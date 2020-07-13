module spectral_initialize_fields_mod

! epg: we added "error_mesg, FATAL, and file_exist" here so that we can report an error if 
!      the initial_conditions.nc file is missing.
use              fms_mod, only: mpp_pe, mpp_root_pe, write_version_number, file_exist, FATAL, error_mesg

use        constants_mod, only: rdgas

use       transforms_mod, only: trans_grid_to_spherical, trans_spherical_to_grid, vor_div_from_uv_grid, &
     uv_grid_from_vor_div, get_grid_domain, get_spec_domain, area_weighted_global_mean
!mj initial conditions
use     time_manager_mod, only: time_type

implicit none
private

public :: spectral_initialize_fields

character(len=128), parameter :: version = &
'$Id: spectral_initialize_fields.f90,v 10.0 2003/10/24 22:00:59 fms Exp $'

character(len=128), parameter :: tagname = &
'$Name: lima $'

logical :: entry_to_logfile_done = .false.

! epg: this netcdf include file is needed to load in specified initial
! conditions.  Only used if choice_of_init == 3
include 'netcdf.inc'

contains

!-------------------------------------------------------------------------------------------------
subroutine spectral_initialize_fields(reference_sea_level_press, triang_trunc, choice_of_init, initial_temperature, &
                        surf_geopotential, ln_ps, vors, divs, ts, psg, ug, vg, tg, vorg, divg, lonb, latb, initial_file, Time, init_conds)
  !mj use interpolator for initial conditions
  use interpolator_mod, only: interpolate_type,interpolator_init,CONSTANT,interpolator
  use press_and_geopot_mod,only: pressure_variables
real,    intent(in) :: reference_sea_level_press
logical, intent(in) :: triang_trunc
integer, intent(in) :: choice_of_init
real,    intent(in) :: initial_temperature

real,    intent(in),  dimension(:,:    ) :: surf_geopotential
complex, intent(out), dimension(:,:    ) :: ln_ps
complex, intent(out), dimension(:,:,:  ) :: vors, divs, ts
real,    intent(out), dimension(:,:    ) :: psg
real,    intent(out), dimension(:,:,:  ) :: ug, vg, tg
real,    intent(out), dimension(:,:,:  ) :: vorg, divg
real,    intent(in),  dimension(:      ),optional :: lonb, latb !mj initial conditions
character(len=*), intent(in),optional             :: initial_file
type(time_type), intent(in),optional              :: Time
type(interpolate_type),optional,intent(out)       :: init_conds

real, allocatable, dimension(:,:) :: ln_psg

real :: initial_sea_level_press, global_mean_psg
real :: initial_perturbation   = 1.e-7

integer :: ms, me, ns, ne, is, ie, js, je, num_levels

! epg: needed to load in initial conditions from a netcdf file
!      code was initially developed by Lorenzo Polvani; hence lmp
! mj: generalisation to use interpolator capabilities
real, allocatable,dimension(:,:,:) :: lmptmp
real, allocatable,dimension(:,:,:) :: p_half,ln_p_half,p_full,ln_p_full 
! --------

if(.not.entry_to_logfile_done) then
  call write_version_number(version, tagname)
  entry_to_logfile_done = .true.
endif

num_levels = size(ug,3)
call get_grid_domain(is, ie, js, je)
call get_spec_domain(ms, me, ns, ne)
allocate(ln_psg(is:ie, js:je))

initial_sea_level_press = reference_sea_level_press  

ug      = 0.
vg      = 0.
tg      = 0.
psg     = 0.
vorg    = 0.
divg    = 0.

vors  = (0.,0.)
divs  = (0.,0.)
ts    = (0.,0.)
ln_ps = (0.,0.)

tg     = initial_temperature
ln_psg = log(initial_sea_level_press) - surf_geopotential/(rdgas*initial_temperature)
psg    = exp(ln_psg)

if(choice_of_init == 1) then  ! perturb temperature field
  if(is <= 1 .and. ie >= 1 .and. js <= 1 .and. je >= 1) then
    tg(1,1,:) = tg(1,1,:) + 1.0
  endif
endif

if(choice_of_init == 2) then   ! initial vorticity perturbation used in benchmark code
  if(ms <= 1 .and. me >= 1 .and. ns <= 3 .and. ne >= 3) then
    vors(2-ms,4-ns,num_levels  ) = initial_perturbation
    vors(2-ms,4-ns,num_levels-1) = initial_perturbation
    vors(2-ms,4-ns,num_levels-2) = initial_perturbation
  endif
  if(ms <= 5 .and. me >= 5 .and. ns <= 3 .and. ne >= 3) then
    vors(6-ms,4-ns,num_levels  ) = initial_perturbation
    vors(6-ms,4-ns,num_levels-1) = initial_perturbation
    vors(6-ms,4-ns,num_levels-2) = initial_perturbation
  endif
  if(ms <= 1 .and. me >= 1 .and. ns <= 2 .and. ne >= 2) then
    vors(2-ms,3-ns,num_levels  ) = initial_perturbation
    vors(2-ms,3-ns,num_levels-1) = initial_perturbation
    vors(2-ms,3-ns,num_levels-2) = initial_perturbation
  endif
  if(ms <= 5 .and. me >= 5 .and. ns <= 2 .and. ne >= 2) then
    vors(6-ms,3-ns,num_levels  ) = initial_perturbation
    vors(6-ms,3-ns,num_levels-1) = initial_perturbation
    vors(6-ms,3-ns,num_levels-2) = initial_perturbation
  endif
  call uv_grid_from_vor_div(vors, divs, ug, vg)
endif

! mj initial conditions: use of interpolator capabilities, from a file with name INPUT/$(initial_file).nc
if (choice_of_init == 3) then !initialize with prescribed input
   print*,'INITIALISING INTERPOLATOR'
   call interpolator_init(init_conds, trim(initial_file)//'.nc', lonb, latb, data_out_of_bounds=(/CONSTANT/))
   ! we will need all of these just to get p_half.
   allocate(p_full(size(psg,1), size(psg,2), num_levels))
   allocate(ln_p_full(size(psg,1), size(psg,2), num_levels))
   allocate(p_half(size(psg,1), size(psg,2), num_levels+1))
   allocate(ln_p_half(size(psg,1), size(psg,2), num_levels+1))
   ! then read psg from file
   call interpolator(init_conds, Time, psg, 'ps', is, js)
   ln_psg = log(psg(:,:))
   ! use psg to compute p_half
   call pressure_variables(p_half, ln_p_half, p_full, ln_p_full, psg)
   ! forget about all other pressure variables which we don't need
   deallocate(ln_p_half,p_full,ln_p_full)
   ! interpolate onto full 3D field
   call interpolator(init_conds, Time, p_half, ug, 'ucomp', is, js)
   call interpolator(init_conds, Time, p_half, vg, 'vcomp', is, js)
   call interpolator(init_conds, Time, p_half, tg, 'temp', is, js)
 
   ! and lastly, let us know that it worked!
   if(mpp_pe() == mpp_root_pe()) then
      print *, 'initial dynamical fields read in from initial_conditions.nc'
   endif
 
endif


!  initial spectral fields (and spectrally-filtered) grid fields

call trans_grid_to_spherical(tg, ts)
call trans_spherical_to_grid(ts, tg)

call trans_grid_to_spherical(ln_psg, ln_ps)
call trans_spherical_to_grid(ln_ps,  ln_psg)
psg = exp(ln_psg)

call vor_div_from_uv_grid(ug, vg, vors, divs, triang=triang_trunc)
call uv_grid_from_vor_div(vors, divs, ug, vg)
call trans_spherical_to_grid(vors, vorg)
call trans_spherical_to_grid(divs, divg)

!  compute and print mean surface pressure
global_mean_psg = area_weighted_global_mean(psg)
if(mpp_pe() == mpp_root_pe()) then
  print '("mean surface pressure=",f9.4," mb")',.01*global_mean_psg
endif

return
end subroutine spectral_initialize_fields
!================================================================================

end module spectral_initialize_fields_mod
