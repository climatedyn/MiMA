module atmos_ozone_tracer_mod
! <CONTACT EMAIL="coding@martinjucker.com">
!   Martin Jucker
! </CONTACT>

! <DESCRIPTION>
!   This module presents an implementation of a tracer.
!   It was created from atmos_radon_mod as template.   
! </DESCRIPTION>

!-----------------------------------------------------------------------

  use            fms_mod, only : file_exist, &
                                 open_namelist_file, check_nml_error, close_file,  &
                                 write_version_number, &
                                 mpp_pe, &
                                 mpp_root_pe, &
                                 error_mesg, &
                                 FATAL,WARNING, NOTE, &
                                 stdlog
use     time_manager_mod, only : time_type
use     diag_manager_mod, only : send_data,            &
                                 register_static_field
use   tracer_manager_mod, only : get_tracer_index
use    field_manager_mod, only : MODEL_ATMOS
use     interpolator_mod, only : interpolator_init,ZERO,CONSTANT,interpolator, &
                                 interpolate_type,interpolator_end


implicit none
private
!-----------------------------------------------------------------------
!----- interfaces -------

public  atmos_ozone_tracer_sourcesink, atmos_ozone_tracer_init, atmos_ozone_tracer_end

!-----------------------------------------------------------------------
!----------- namelist -------------------
!-----------------------------------------------------------------------

logical :: do_nudge_ozone = .false.
character(len=256) :: ozone_file='ozone'              !  file name of ozone file to read
character(len=256) :: ozone_name='none'               !   variable name in ozone file. defaults
real :: tnudge = 0.0                                  !  nudging time scale [days]. No nudging if zero

namelist /atmos_ozone_nml/  &
                            do_nudge_ozone, tnudge, ozone_file, ozone_name


!--- Arrays to help calculate tracer sources/sinks ---

character(len=6), parameter :: module_name = 'tracer'

type(interpolate_type),save                :: o3_tracer_interp ! use external file for ozone
integer                                    :: is_loc,js_loc    ! parallelization

logical :: module_is_initialized=.FALSE.


!---- version number -----
character(len=128) :: version = '$Id: atmos_ozone.f90,v 1.0 2020/09/10 fms Exp $'
character(len=128) :: tagname = '$Name: lima $'
!-----------------------------------------------------------------------

contains


!#######################################################################
 subroutine atmos_ozone_tracer_sourcesink (ozone, ozone_dt,  phalf, Time )

!-----------------------------------------------------------------------
   real, intent(in),  dimension(:,:,:) :: ozone, phalf
   real, intent(out), dimension(:,:,:) :: ozone_dt
   type(time_type), intent(in)         :: Time
!-----------------------------------------------------------------------
   real, dimension(size(ozone,1),size(ozone,2),size(ozone,3)) ::  nudge !&
!        source, sink
!-----------------------------------------------------------------------
   if ( .not. do_nudge_ozone ) then
      ozone_dt = 0.0
      return
   endif
   call interpolator( o3_tracer_interp,  Time, phalf, nudge, ozone_name, is_loc, js_loc )

!------- tendency ------------------

   ozone_dt = -(ozone-nudge)/(tnudge*84600.)
      

!-----------------------------------------------------------------------

 end subroutine atmos_ozone_tracer_sourcesink
!</SUBROUTINE>

!#######################################################################
 subroutine atmos_ozone_tracer_init (lonb, latb, is, js, phalf, Time, r)

!-----------------------------------------------------------------------
!
!   r    = tracer fields dimensioned as (nlon,nlat,nlev)
!
!-----------------------------------------------------------------------
real,             intent(in),    dimension(:)                :: lonb,latb 
integer,          intent(in)                                 :: is, js
real,             intent(in),    dimension(:,:,:),optional   :: phalf
type(time_type),  intent(in),                     optional   :: Time
real,             intent(inout), dimension(:,:,:),optional   :: r

!
!-----------------------------------------------------------------------
!
!--- interpolation object
integer :: ierr,io,unit

      if (module_is_initialized) return

!---- write namelist ------------------

! read namelist and copy to logfile
      unit = open_namelist_file ( )
      ierr=1
      do while (ierr /= 0)
         read  (unit, nml=atmos_ozone_nml, iostat=io, end=10)
         ierr = check_nml_error (io, 'atmos_ozone_nml')
      enddo
10    call close_file (unit)
          
      call write_version_number (version, tagname)
      if ( mpp_pe() == mpp_root_pe() ) &
        write ( stdlog(), nml=atmos_ozone_nml )
 
      !
      call interpolator_init (o3_tracer_interp, trim(ozone_file)//'.nc', lonb, latb, data_out_of_bounds=(/CONSTANT/))
      if ( trim(ozone_name) .eq. 'none' ) then
         ozone_name = trim(ozone_file)
      endif

      is_loc = is
      js_loc = js
         
      if ( present(r) ) then
         call interpolator( o3_tracer_interp, Time, phalf, r, ozone_name, is, js )
         r = max(0.0,r)
      endif


      module_is_initialized = .TRUE.


!-----------------------------------------------------------------------

 end subroutine atmos_ozone_tracer_init
!</SUBROUTINE>

!#######################################################################

 subroutine atmos_ozone_tracer_end
   
      call interpolator_end(o3_tracer_interp)
 
      module_is_initialized = .FALSE.

 end subroutine atmos_ozone_tracer_end
!</SUBROUTINE>


end module atmos_ozone_tracer_mod



