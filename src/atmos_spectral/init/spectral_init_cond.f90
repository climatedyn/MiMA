module spectral_init_cond_mod

use               fms_mod, only: mpp_pe, mpp_root_pe, error_mesg, FATAL, field_size, stdlog, file_exist, &
                                 write_version_number, close_file, check_nml_error, read_data, open_namelist_file

use               mpp_mod, only: mpp_chksum

use       mpp_domains_mod, only: mpp_get_global_domain

use         constants_mod, only: grav, pi

use   vert_coordinate_mod, only: compute_vert_coord

use        transforms_mod, only: get_grid_boundaries, get_deg_lon, get_deg_lat, trans_grid_to_spherical, &
                                 trans_spherical_to_grid, get_grid_domain, get_spec_domain
use           spec_mpp_mod,only: grid_domain, spectral_domain

use  press_and_geopot_mod, only: press_and_geopot_init, pressure_variables

use spectral_initialize_fields_mod, only: spectral_initialize_fields

use       topog_regularization_mod, only: compute_lambda, regularize

use                 topography_mod, only: gaussian_topog_init, get_topog_mean, get_ocean_mask
!mj initial conditions
use               time_manager_mod, only: time_type
use               interpolator_mod, only: interpolate_type

implicit none
private

character(len=128), parameter :: version = &
'$Id: spectral_init_cond.f90,v 10.0 2003/10/24 22:00:59 fms Exp $'

character(len=128), parameter :: tagname = &
'$Name: lima $'

public :: spectral_init_cond

real :: initial_temperature=264.


namelist / spectral_init_cond_nml / initial_temperature

Contains

!=========================================================================================================================

subroutine spectral_init_cond(reference_sea_level_press, triang_trunc, use_virtual_temperature, topography_option, &
                              vert_coord_option, vert_difference_option, scale_heights, surf_res,    &
                              p_press, p_sigma, exponent, ocean_topog_smoothing, pk, bk, vors, divs, &
                              ts, ln_ps, ug, vg, tg, psg, vorg, divg, surf_geopotential, ocean_mask, specify_initial_conditions, random_perturbation, &
                              lonb, latb, initial_file, Time, init_conds) !mj initial conditions

real,    intent(in) :: reference_sea_level_press
logical, intent(in) :: triang_trunc, use_virtual_temperature
character(len=*), intent(in) :: topography_option, vert_coord_option, vert_difference_option
real,    intent(in) :: scale_heights, surf_res, p_press, p_sigma, exponent, ocean_topog_smoothing
real,    intent(out), dimension(:) :: pk, bk
complex, intent(out), dimension(:,:,:) :: vors, divs, ts
complex, intent(out), dimension(:,:  ) :: ln_ps
real,    intent(out), dimension(:,:,:) :: ug, vg, tg
real,    intent(out), dimension(:,:  ) :: psg
real,    intent(out), dimension(:,:,:) :: vorg, divg
real,    intent(out), dimension(:,:  ) :: surf_geopotential
logical, optional, intent(in), dimension(:,:) :: ocean_mask
logical, intent(in) :: specify_initial_conditions   !epg+ray
real,    intent(in) :: random_perturbation                ! mj initial conditions

real,    intent(in), dimension(:), optional :: lonb, latb ! mj initial conditions
character(len=*), intent(in), optional      :: initial_file ! mj initial conditions
type(time_type), intent(in), optional       :: Time
type(interpolate_type),intent(out),optional :: init_conds


! epg+ray: choice_of_init is used by spectral_initialize_fields to actually set up initial conditions
integer :: choice_of_init = 2
integer :: unit, ierr, io

!------------------------------------------------------------------------------------------------

! epg+ray: if we want to specify the initial conditions, set choice_of_init to 3
if(specify_initial_conditions) then
  choice_of_init=3
endif

unit = open_namelist_file()
ierr=1
do while (ierr /= 0)
  read(unit, nml=spectral_init_cond_nml, iostat=io, end=20)
  ierr = check_nml_error (io, 'spectral_init_cond_nml')
enddo
20 call close_file (unit)
call write_version_number(version, tagname)
if(mpp_pe() == mpp_root_pe()) write (stdlog(), nml=spectral_init_cond_nml)

call compute_vert_coord (vert_coord_option, scale_heights, surf_res, exponent, p_press, p_sigma, reference_sea_level_press, pk,bk)

call get_topography(topography_option, ocean_topog_smoothing, surf_geopotential, ocean_mask)
call press_and_geopot_init(pk, bk, use_virtual_temperature, vert_difference_option, surf_geopotential)

if (choice_of_init .eq. 3) then
   call spectral_initialize_fields(reference_sea_level_press, triang_trunc, choice_of_init, initial_temperature, &
        surf_geopotential, ln_ps, vors, divs, ts, psg, ug, vg, tg, vorg, divg, random_perturbation, &
        lonb, latb, initial_file, Time, init_conds)
else
   call spectral_initialize_fields(reference_sea_level_press, triang_trunc, choice_of_init, initial_temperature, &
        surf_geopotential, ln_ps, vors, divs, ts, psg, ug, vg, tg, vorg, divg, random_perturbation)
endif

call check_vert_coord(size(ug,3), psg)

return
end subroutine spectral_init_cond

!================================================================================

subroutine check_vert_coord(num_levels, psg)
integer, intent(in) :: num_levels
real, intent(in), dimension(:,:) :: psg
real, dimension(size(psg,1), size(psg,2), num_levels  ) :: p_full, ln_p_full
real, dimension(size(psg,1), size(psg,2), num_levels+1) :: p_half, ln_p_half
integer :: i,j,k

call pressure_variables(p_half, ln_p_half, p_full, ln_p_full, psg)
do k=1,size(p_full,3)
  do j=1,size(p_full,2)
    do i=1,size(p_full,1)
      if(p_half(i,j,k+1) < p_half(i,j,k)) then
        call error_mesg('check_vert_coord','Pressure levels intersect.',FATAL)
      endif
    enddo
  enddo
enddo

return
end subroutine check_vert_coord
!================================================================================

subroutine get_topography(topography_option, ocean_topog_smoothing, surf_geopotential, ocean_mask_in)

character(len=*), intent(in) :: topography_option
real,    intent(in) :: ocean_topog_smoothing
real,    intent(out), dimension(:,:) :: surf_geopotential
logical, intent(in), optional, dimension(:,:) :: ocean_mask_in
real,    dimension(size(surf_geopotential,1)  ) :: deg_lon
real,    dimension(size(surf_geopotential,2)  ) :: deg_lat
real,    dimension(size(surf_geopotential,1),size(surf_geopotential,2)) :: surf_height
logical, dimension(size(surf_geopotential,1),size(surf_geopotential,2)) :: ocean_mask
complex, allocatable, dimension(:,:) :: spec_tmp
real :: fraction_smoothed, lambda
integer :: is, ie, js, je, ms, me, ns, ne, global_num_lon, global_num_lat
real, allocatable, dimension(:) :: blon, blat
logical :: topo_file_exists, water_file_exists
integer, dimension(4) :: siz
character(len=12) :: ctmp1='     by     ', ctmp2='     by     '

if(trim(topography_option) == 'flat') then
   surf_geopotential = 0.

else if(trim(topography_option) == 'input') then
   if(file_exist('INPUT/topography.data.nc')) then
     call mpp_get_global_domain(grid_domain, xsize=global_num_lon, ysize=global_num_lat)
     call field_size('INPUT/topography.data.nc', 'zsurf', siz)
     if ( siz(1) == global_num_lon .or. siz(2) == global_num_lat ) then
       call read_data('INPUT/topography.data.nc', 'zsurf', surf_height, grid_domain)
     else
       write(ctmp1(1: 4),'(i4)') siz(1)
       write(ctmp1(9:12),'(i4)') siz(2)
       write(ctmp2(1: 4),'(i4)') global_num_lon
       write(ctmp2(9:12),'(i4)') global_num_lat
       call error_mesg ('get_topography','Topography file contains data on a '// &
              ctmp1//' grid, but atmos model grid is '//ctmp2, FATAL)
     endif

!    Spectrally truncate the topography
     call get_spec_domain(ms, me, ns, ne)
     allocate(spec_tmp(ms:me, ns:ne))
     call trans_grid_to_spherical(surf_height,spec_tmp)
     call trans_spherical_to_grid(spec_tmp,surf_height)
     deallocate(spec_tmp)
     surf_geopotential = grav*surf_height
   else
     call error_mesg('get_topography','topography_option="'//trim(topography_option)//'"'// &
                     ' but INPUT/topography.data.nc does not exist', FATAL)
   endif

else if(trim(topography_option) == 'interpolated') then

!  Get realistic topography
   call get_grid_domain(is, ie, js, je)
   allocate(blon(is:ie+1), blat(js:je+1))
   call get_grid_boundaries(blon, blat)
   topo_file_exists = get_topog_mean(blon, blat, surf_height)
   if(.not.topo_file_exists) then
     call error_mesg('get_topography','topography_option="'//trim(topography_option)//'"'// &
                     ' but topography data file does not exist', FATAL)
   endif
   surf_geopotential = grav*surf_height

   if(ocean_topog_smoothing == 0.) then
!    Spectrally truncate the realistic topography
     call get_spec_domain(ms, me, ns, ne)
     allocate(spec_tmp(ms:me, ns:ne))
     call trans_grid_to_spherical(surf_geopotential,spec_tmp)
     call trans_spherical_to_grid(spec_tmp,surf_geopotential)
     deallocate(spec_tmp)
   else
!    Do topography regularization
     if(present(ocean_mask_in)) then
       ocean_mask = ocean_mask_in
     else
       water_file_exists = get_ocean_mask(blon, blat, ocean_mask)
       if(.not.water_file_exists) then
         call error_mesg('get_topography','topography_option="'//trim(topography_option)//'"'// &
                         ' and ocean_mask is not present but water data file does not exist', FATAL)
       endif
     endif
     call compute_lambda(ocean_topog_smoothing, ocean_mask, surf_geopotential, lambda, fraction_smoothed)

!  Note that the array surf_height is used here for the smoothed surf_geopotential,
!  then immediately loaded back into surf_geopotential
     call regularize(lambda, ocean_mask, surf_geopotential, surf_height, fraction_smoothed)
     surf_geopotential = surf_height

     if(mpp_pe() == mpp_root_pe()) then
       print '(/,"Message from subroutine get_topography:")'
       print '("lambda=",1pe16.8,"  fraction_smoothed=",1pe16.8,/)',lambda,fraction_smoothed
     endif
   endif
   deallocate(blon, blat)

else if(trim(topography_option) == 'gaussian') then
   call get_deg_lon(deg_lon)
   call get_deg_lat(deg_lat)
   call gaussian_topog_init(deg_lon*pi/180, deg_lat*pi/180, surf_height)
   surf_geopotential = grav*surf_height
else
   call error_mesg('get_topography','"'//trim(topography_option)//'" is an invalid value for topography_option.', FATAL)
endif

return
end subroutine get_topography
!=======================================================================================================
subroutine print_chksum(text, vors, divs, ts, ln_ps, ug, vg, tg, psg, vorg, divg, surf_geopotential)
character(len=*), intent(in) :: text
complex, intent(in), dimension(:,:,:) :: vors, divs, ts
complex, intent(in), dimension(:,:  ) :: ln_ps
real,    intent(in), dimension(:,:,:) :: ug, vg, tg, vorg, divg
real,    intent(in), dimension(:,:  ) :: psg, surf_geopotential

integer(kind=kind(ug)) :: chksum_vors, chksum_divs, chksum_ts, chksum_ln_ps, chksum_ug, chksum_vg
integer(kind=kind(ug)) :: chksum_tg, chksum_psg, chksum_vorg, chksum_divg, chksum_wg_full, chksum_surf_geo

if (mpp_pe() == mpp_root_pe()) print '(/,a)',text

chksum_vors    = mpp_chksum(vors)
chksum_divs    = mpp_chksum(divs)
chksum_ts      = mpp_chksum(ts)
chksum_ln_ps   = mpp_chksum(ln_ps)
chksum_ug      = mpp_chksum(ug)
chksum_vg      = mpp_chksum(vg)
chksum_tg      = mpp_chksum(tg)
chksum_psg     = mpp_chksum(psg)
chksum_vorg    = mpp_chksum(vorg)
chksum_divg    = mpp_chksum(divg)
chksum_surf_geo = mpp_chksum(surf_geopotential)

if (mpp_pe() == mpp_root_pe()) then
  print '("mpp_chksum(vors   )=",z17)',chksum_vors
  print '("mpp_chksum(divs   )=",z17)',chksum_divs
  print '("mpp_chksum(ts     )=",z17)',chksum_ts
  print '("mpp_chksum(ln_ps  )=",z17)',chksum_ln_ps
  print '("mpp_chksum(ug     )=",z17)',chksum_ug
  print '("mpp_chksum(vg     )=",z17)',chksum_vg
  print '("mpp_chksum(tg     )=",z17)',chksum_tg
  print '("mpp_chksum(psg    )=",z17)',chksum_psg
  print '("mpp_chksum(vorg   )=",z17)',chksum_vorg
  print '("mpp_chksum(divg   )=",z17)',chksum_divg
  print '("mpp_chksum(surf_geopotential)=",z17)',chksum_surf_geo
endif

return
end subroutine print_chksum
!================================================================================
end module spectral_init_cond_mod
