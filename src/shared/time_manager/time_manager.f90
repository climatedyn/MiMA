module time_manager_mod

! <CONTACT EMAIL="fms@gfdl.noaa.gov">
!   fms
! </CONTACT>

! <HISTORY SRC="http://www.gfdl.noaa.gov/fms-cgi-bin/cvsweb.cgi/FMS/"/>

! <OVERVIEW>
!   A software package that provides a set of simple interfaces for
!   modelers to perform computations related to time and dates.
! </OVERVIEW>

! <DESCRIPTION>
!    The module defines a type that can be used to represent discrete
!    times (accurate to one second) and to map these times into dates
!    using a variety of calendars. A time is mapped to a date by
!    representing the time with respect to an arbitrary base date (refer
!    to <B>NOTES</B> section for the <LINK SRC="#base date">base date</LINK> setting).
!
!    The time_manager provides a single defined type, time_type, which is
!    used to store time and date quantities. A time_type is a positive
!    definite quantity that represents an interval of time. It can be
!    most easily thought of as representing the number of seconds in some
!    time interval. A time interval can be mapped to a date under a given
!    calendar definition by using it to represent the time that has passed
!    since some base date. A number of interfaces are provided to operate
!    on time_type variables and their associated calendars. Time intervals
!    can be as large as n days where n is the largest number represented by
!    the default integer type on a compiler. This is typically considerably
!    greater than 10 million years (assuming 32 bit integer representation)
!    which is likely to be adequate for most applications. The description
!    of the interfaces is separated into two sections. The first deals with
!    operations on time intervals while the second deals with operations
!    that convert time intervals to dates for a given calendar.
! </DESCRIPTION>

! <DATA NAME="time_type" TYPE="derived type">
!    Derived-type data variable used to store time and date quantities. It
!    contains two PRIVATE variables: seconds and days.
! </DATA>

use fms_mod, only: error_mesg, FATAL, WARNING, write_version_number, stdout, stdlog, &
                   mpp_pe, mpp_root_pe, close_file, open_namelist_file, check_nml_error

implicit none
private

! Module defines a single type
public time_type

! Operators defined on time_type
public operator(+),  operator(-),   operator(*),   operator(/),  &
       operator(>),  operator(>=),  operator(==),  operator(/=), &
       operator(<),  operator(<=),  operator(//)

! Subroutines and functions operating on time_type
public set_time, increment_time, decrement_time, get_time, interval_alarm
public repeat_alarm, time_type_to_real, real_to_time_type

! List of available calendar types
public    THIRTY_DAY_MONTHS,    JULIAN,    GREGORIAN,  NOLEAP,   NO_CALENDAR

! Subroutines and functions involving relations between time and calendar
public set_calendar_type, get_calendar_type
public set_date,       set_date_gregorian,         set_date_julian, &
                       set_date_thirty,            set_date_no_leap
public get_date,       get_date_gregorian,         get_date_julian, &
                       get_date_thirty,            get_date_no_leap
public increment_date, increment_gregorian,        increment_julian, &
                       increment_thirty,           increment_no_leap
public decrement_date, decrement_gregorian,        decrement_julian, &
                       decrement_thirty,           decrement_no_leap
public days_in_month,  days_in_month_gregorian,    days_in_month_julian, &
                       days_in_month_no_leap,      days_in_month_thirty
public leap_year,      leap_year_gregorian,        leap_year_julian, &
                       leap_year_no_leap,          leap_year_thirty
public length_of_year, length_of_year_thirty,      length_of_year_julian, &
                       length_of_year_gregorian,   length_of_year_no_leap
public days_in_year,   days_in_year_thirty,        days_in_year_julian, &
                       days_in_year_gregorian,     days_in_year_no_leap
public month_name

public valid_calendar_types

! Subroutines for printing version number and time type
public :: time_manager_init, print_time, print_date

!====================================================================

! Global data to define calendar type
integer, parameter :: THIRTY_DAY_MONTHS = 1,      JULIAN = 2, &
                      GREGORIAN = 3,              NOLEAP = 4, &
                      NO_CALENDAR = 0
integer, private :: calendar_type = NO_CALENDAR
integer, parameter :: max_type = 4

! Define number of days per month
integer, private :: days_per_month(12) = (/31,28,31,30,31,30,31,31,30,31,30,31/)

! time_type is implemented as seconds and days to allow for larger intervals
type time_type
   private
   integer(8):: seconds
   integer(8):: days
end type time_type

!======================================================================

interface operator (+);   module procedure time_plus;        end interface
interface operator (-);   module procedure time_minus;       end interface
interface operator (*);   module procedure time_scalar_mult 
                          module procedure scalar_time_mult; end interface
interface operator (/);   module procedure time_scalar_divide
                          module procedure time_divide;      end interface
interface operator (>);   module procedure time_gt;          end interface
interface operator (>=);  module procedure time_ge;          end interface
interface operator (<);   module procedure time_lt;          end interface
interface operator (<=);  module procedure time_le;          end interface
interface operator (==);  module procedure time_eq;          end interface
interface operator (/=);  module procedure time_ne;          end interface
interface operator (//);  module procedure time_real_divide; end interface

!======================================================================

interface set_time
  module procedure set_time_i8, set_time_i, set_time_c
end interface

interface set_date
  module procedure set_date_i, set_date_c
end interface

!======================================================================

character(len=128) :: version='$Id: time_manager.f90,v 12.0 2005/04/14 18:02:05 fms Exp $'
character(len=128) :: tagname='$Name: lima $'
logical :: module_is_initialized = .false.

!======================================================================

logical :: zero_year_warning = .true.

namelist / time_manager_nml / zero_year_warning

!======================================================================
contains

! First define all operations on time intervals independent of calendar

!=========================================================================
! <FUNCTION NAME="set_time">

!   <OVERVIEW>
!     Given some number of seconds and days, returns the
!     corresponding time_type.
!   </OVERVIEW>
!   <DESCRIPTION>
!     Given some number of seconds and days, returns the
!     corresponding time_type.
!   </DESCRIPTION>
!   <TEMPLATE>
!     set_time(seconds, days)
!   </TEMPLATE>

!   <IN NAME="seconds" UNITS="" TYPE="integer" DIM="(scalar)">
!     A number of seconds (can be greater than 86400),  must be positive.
!   </IN>
!   <IN NAME="days" UNITS="" TYPE="integer" DIM="(scalar)">
!     A number of days, must be positive.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="" DIM="" DEFAULT="">
!     A time interval corresponding to this number of days and seconds.
!   </OUT>

function set_time_i8(seconds, days)

! Returns a time interval corresponding to this number of days and seconds.
! The arguments must not be negative but are otherwise unrestricted.

implicit none

type(time_type) :: set_time_i8
integer(8), intent(in) :: seconds
integer(8), intent(in), optional :: days
integer(8) :: days_in, secperday

secperday = INT(60*60*24,8)

days_in = 0;  if (present(days)) days_in = days

! Negative time offset is illegal
if(seconds < 0 .or. days_in < 0) call error_handler('Negative input in set_time_i')

! Make sure seconds greater than a day are fixed up
set_time_i8%seconds = seconds - seconds / secperday * secperday

! Check for overflow on days before doing operation
if(seconds / secperday  >= huge(days_in) - days_in) &
   call error_handler('Integer overflow in days in set_time_i')
set_time_i8%days = days_in + seconds / secperday

end function set_time_i8
! </FUNCTION>
!---------------------------------------------------------------------------
function set_time_i(seconds, days)

! Returns a time interval corresponding to this number of days and seconds.
! The arguments must not be negative but are otherwise unrestricted.

implicit none

type(time_type) :: set_time_i
integer, intent(in) :: seconds
integer, intent(in), optional :: days

set_time_i = set_time_i8(INT(seconds,8),INT(days,8))

end function set_time_i
! </FUNCTION>
!---------------------------------------------------------------------------

function set_time_c(string)

implicit none

type(time_type) :: set_time_c
character(len=*), intent(in) :: string
character(len=4) :: formt='(i )'
integer :: i1, i2
integer(8) :: day, second
character(len=32) :: string_sifted_left

string_sifted_left = adjustl(string)
i1 = index(trim(string_sifted_left),' ')
if(i1 == 0) then
  call error_mesg('set_time_c','Form of character time stamp is incorrect.'// &
  ' When NO_CALENDAR is in effect, '// &
  ' it must include days and seconds.'// &
  ' The character time stamp is: '//trim(string),FATAL)
endif
if(index(string,'-') /= 0 .or. index(string,':') /= 0) then
  call error_mesg('set_time_c','Form of character time stamp is incorrect.'// &
  ' When NO_CALENDAR is in effect, it must consist of days and seconds separated by a blank.'// &
  ' The time stamp is: '//trim(string)//  &
  '   Note: use set_date if time stamp is a calendar date.',FATAL)
endif
write(formt(3:3),'(i1)') i1-1
read(string_sifted_left(1:i1-1),formt) day
i2 = len_trim(cut0(string_sifted_left))
write(formt(3:3),'(i1)') i2-i1
read(string_sifted_left(i1+1:i2),formt) second
set_time_c = set_time(second, day)

end function set_time_c
!---------------------------------------------------------------------------
! <SUBROUTINE NAME="get_time">

!   <OVERVIEW>
!     Given a time interval, returns the corresponding seconds and days.
!   </OVERVIEW>
!   <DESCRIPTION>
!     Given a time interval, returns the corresponding seconds and days.
!   </DESCRIPTION>
!   <TEMPLATE>
!     get_time(time, seconds, days)
!   </TEMPLATE>

!   <IN NAME="time" TYPE="time_type">
!     A time interval. 
!   </IN>
!   <OUT NAME="seconds" UNITS="" TYPE="integer" DIM="(scalar)">
!     A number of seconds (&lt; 86400).
!   </OUT>
!   <OUT NAME="days" UNITS="" TYPE="integer" DIM="(scalar)">
!     A number of days, must be positive.
!   </OUT>

subroutine get_time(time, seconds, days)

! Returns days and seconds ( < 86400 ) corresponding to a time.

implicit none

type(time_type), intent(in) :: time
integer(8), intent(out) :: seconds
integer(8), intent(out), optional :: days
integer(8), parameter :: secperday = 86400

seconds = time%seconds
if (present(days)) then
  days = time%days
else
  if (time%days > (huge(seconds) - seconds)/secperday) &
  call error_handler('Integer overflow in seconds in get_time use days')
  seconds = seconds + time%days * secperday
endif

end subroutine get_time
! </SUBROUTINE>

!-------------------------------------------------------------------------
! <FUNCTION NAME="increment_time">

!   <OVERVIEW>
!      Given a time and an increment of days and seconds, returns
!      a time that adds this increment to an input time.
!   </OVERVIEW>
!   <DESCRIPTION>
!      Given a time and an increment of days and seconds, returns
!      a time that adds this increment to an input time.
!      Increments a time by seconds and days; increments cannot be negative.     
!   </DESCRIPTION>
!   <TEMPLATE>
!     increment_time(time, seconds, days)
!   </TEMPLATE>

!   <IN NAME="time" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <IN NAME="seconds" UNITS="" TYPE="integer" DIM="(scalar)">
!     Increment of seconds (can be greater than 86400);  must be positive.
!   </IN>
!   <IN NAME="days" UNITS="" TYPE="integer" DIM="(scalar)">
!     Increment of days;  must be positive.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="" DIM="" DEFAULT="">
!     A time that adds this increment to the input time.
!   </OUT>

function increment_time(time, seconds, days)

! Increments a time by seconds and days; increments cannot be negative.
implicit none

type(time_type) :: increment_time
type(time_type), intent(in) :: time
integer(8), intent(in) :: seconds
integer(8), intent(in), optional :: days
integer(8) :: days_in, zero

zero = INT(0,8)

days_in = zero;  if (present(days)) days_in = days

! Increment must be positive definite
if(seconds < zero .or. days_in < zero) &
   call error_handler('Negative increment in increment_time')

! Watch for immediate overflow on days or seconds
if(days_in >= huge(days_in) - time%days) &
   call error_handler('Integer overflow in days in increment_time')
if(seconds >= huge(seconds) - time%seconds) &
   call error_handler('Integer overflow in seconds in increment_time')

increment_time = set_time(time%seconds + seconds, time%days + days_in)

end function increment_time
! </FUNCTION>

!--------------------------------------------------------------------------
! <FUNCTION NAME="decrement_time">

!   <OVERVIEW>
!      Given a time and a decrement of days and seconds, returns
!      a time that subtracts this decrement from an input time. 
!   </OVERVIEW>
!   <DESCRIPTION>
!      Decrements a time by seconds and days; decrements cannot be negative.
!   </DESCRIPTION>
!   <TEMPLATE>
!     Decrement_time(time, seconds, days)
!   </TEMPLATE>

!   <IN NAME="time" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <IN NAME="seconds" UNITS="" TYPE="integer" DIM="(scalar)">
!     Decrement of seconds (can be greater than 86400);  must be positive.
!   </IN>    
!   <IN NAME="days" UNITS="" TYPE="integer" DIM="(scalar)">
!     Decrement of days;  must be positive.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="" DIM="" DEFAULT="">
!      A time that subtracts this decrement from an input time. If
!      the result is negative, it is considered a fatal error.
!   </OUT>

function decrement_time(time, seconds, days)

! Decrements a time by seconds and days; decrements cannot be negative.

implicit none

type(time_type) :: decrement_time
type(time_type), intent(in) :: time
integer(8), intent(in) :: seconds
integer(8), intent(in), optional :: days
integer(8) :: cseconds, cdays, zero, secperday

zero = INT(0,8)
secperday = INT(86400,8)

cdays = zero;  if (present(days)) cdays = days

! Decrement must be positive definite
if(seconds < zero .or. cdays < zero) &
   call error_handler('Negative decrement in decrement_time')

cseconds = time%seconds - seconds
cdays = time%days - cdays

! Borrow if needed
if(cseconds < zero) then
   cdays = cdays - 1 + (cseconds + 1) / secperday
   cseconds = cseconds - secperday * (-1 + (cseconds + 1) / secperday)
end if

! Check for illegal negative time
if(cdays < zero) call error_handler('Negative time results in decrement_time')

decrement_time%seconds = cseconds
decrement_time%days = cdays

end function decrement_time
! </FUNCTION>

!--------------------------------------------------------------------------
! <FUNCTION NAME="time_gt">

!   <OVERVIEW>
!      Returns true if time1 > time2.
!   </OVERVIEW>
!   <DESCRIPTION>
!      Returns true if time1 > time2.
!   </DESCRIPTION>
!   <TEMPLATE>
!     time_gt(time1, time2)
!   </TEMPLATE>

!   <IN NAME="time1" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <IN NAME="time2" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="logical" DIM="" DEFAULT="">
!       Returns true if time1 > time2
!   </OUT>

function time_gt(time1, time2)

! Returns true if time1 > time2

implicit none

logical :: time_gt
type(time_type), intent(in) :: time1, time2

time_gt = (time1%days > time2%days)
if(time1%days == time2%days) time_gt = (time1%seconds > time2%seconds)

end function time_gt
! </FUNCTION>

!--------------------------------------------------------------------------
! <FUNCTION NAME="time_ge">

!   <OVERVIEW>
!      Returns true if time1 >= time2.
!   </OVERVIEW>
!   <DESCRIPTION>
!      Returns true if time1 >= time2.
!   </DESCRIPTION>
!   <TEMPLATE>
!     time_ge(time1, time2)
!   </TEMPLATE>

!   <IN NAME="time1" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <IN NAME="time2" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="logical" DIM="" DEFAULT="">
!       Returns true if time1 >= time2
!   </OUT>

function time_ge(time1, time2)

! Returns true if time1 >= time2

implicit none

logical :: time_ge
type(time_type), intent(in) :: time1, time2

time_ge = (time_gt(time1, time2) .or. time_eq(time1, time2))

end function time_ge
! </FUNCTION>

!--------------------------------------------------------------------------
! <FUNCTION NAME="time_lt">

!   <OVERVIEW>
!      Returns true if time1 < time2.
!   </OVERVIEW>
!   <DESCRIPTION>
!      Returns true if time1 < time2.
!   </DESCRIPTION>
!   <TEMPLATE>
!     time_lt(time1, time2)
!   </TEMPLATE>

!   <IN NAME="time1" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <IN NAME="time2" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="logical" DIM="" DEFAULT="">
!       Returns true if time1 < time2
!   </OUT>

function time_lt(time1, time2)

! Returns true if time1 < time2

implicit none

logical :: time_lt
type(time_type), intent(in) :: time1, time2

time_lt = (time1%days < time2%days)
if(time1%days == time2%days) time_lt = (time1%seconds < time2%seconds)

end function time_lt
! </FUNCTION>

!--------------------------------------------------------------------------
! <FUNCTION NAME="time_le">

!   <OVERVIEW>
!      Returns true if time1 <= time2.
!   </OVERVIEW>
!   <DESCRIPTION>
!      Returns true if time1 <= time2.
!   </DESCRIPTION>
!   <TEMPLATE>
!     time_le(time1, time2)
!   </TEMPLATE>

!   <IN NAME="time1" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <IN NAME="time2" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="logical" DIM="" DEFAULT="">
!       Returns true if time1 <= time2
!   </OUT>

function time_le(time1, time2)

! Returns true if time1 <= time2

implicit none

logical :: time_le
type(time_type), intent(in) :: time1, time2

time_le = (time_lt(time1, time2) .or. time_eq(time1, time2))

end function time_le
! </FUNCTION>

!--------------------------------------------------------------------------
! <FUNCTION NAME="time_eq">

!   <OVERVIEW>
!      Returns true if time1 == time2.
!   </OVERVIEW>
!   <DESCRIPTION>
!      Returns true if time1 == time2.
!   </DESCRIPTION>
!   <TEMPLATE>
!     time_eq(time1, time2)
!   </TEMPLATE>

!   <IN NAME="time1" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <IN NAME="time2" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="logical" DIM="" DEFAULT="">
!       Returns true if time1 == time2
!   </OUT>

function time_eq(time1, time2)

! Returns true if time1 == time2

implicit none

logical :: time_eq
type(time_type), intent(in) :: time1, time2

time_eq = (time1%seconds == time2%seconds .and. time1%days == time2%days)

end function time_eq
! </FUNCTION>

!--------------------------------------------------------------------------
! <FUNCTION NAME="time_ne">

!   <OVERVIEW>
!      Returns true if time1 /= time2.
!   </OVERVIEW>
!   <DESCRIPTION>
!      Returns true if time1 /= time2.
!   </DESCRIPTION>
!   <TEMPLATE>
!     time_ne(time1, time2)
!   </TEMPLATE>

!   <IN NAME="time1" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <IN NAME="time2" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="logical" DIM="" DEFAULT="">
!       Returns true if time1 /= time2
!   </OUT>

function time_ne(time1, time2)

! Returns true if time1 /= time2

implicit none

logical :: time_ne
type(time_type), intent(in) :: time1, time2

time_ne = (.not. time_eq(time1, time2))

end function time_ne
! </FUNCTION>

!-------------------------------------------------------------------------
! <FUNCTION NAME="time_plus">

!   <OVERVIEW>
!       Returns sum of two time_types.
!   </OVERVIEW>
!   <DESCRIPTION>
!       Returns sum of two time_types.
!   </DESCRIPTION>
!   <TEMPLATE>
!     time_plus(time1, time2)
!   </TEMPLATE>

!   <IN NAME="time1" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <IN NAME="time2" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="time_type" DIM="" DEFAULT="">
!       Returns sum of two time_types.
!   </OUT>

function time_plus(time1, time2)

! Returns sum of two time_types

implicit none

type(time_type) :: time_plus
type(time_type), intent(in) :: time1, time2

time_plus = increment_time(time1, time2%seconds, time2%days)

end function time_plus
! </FUNCTION>

!-------------------------------------------------------------------------
! <FUNCTION NAME="time_minus">

!   <OVERVIEW>
!       Returns difference of two time_types.
!   </OVERVIEW>
!   <DESCRIPTION>
!       Returns difference of two time_types. WARNING: a time type is positive 
!       so by definition time1 - time2  is the same as time2 - time1.
!   </DESCRIPTION>
!   <TEMPLATE>
!     time_minus(time1, time2)
!   </TEMPLATE>

!   <IN NAME="time1" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <IN NAME="time2" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="time_type" DIM="" DEFAULT="">
!       Returns difference of two time_types.
!   </OUT>

function time_minus(time1, time2)

! Returns difference of two time_types. WARNING: a time type is positive 
! so by definition time1 - time2  is the same as time2 - time1.

implicit none

type(time_type) :: time_minus
type(time_type), intent(in) :: time1, time2

if(time1 > time2) then
   time_minus = decrement_time(time1, time2%seconds, time2%days)
else 
   time_minus = decrement_time(time2, time1%seconds, time1%days)
endif

end function time_minus
! </FUNCTION>

!--------------------------------------------------------------------------
! <FUNCTION NAME="time_scalar_mult">

!   <OVERVIEW>
!       Returns time multiplied by integer factor n.
!   </OVERVIEW>
!   <DESCRIPTION>
!       Returns time multiplied by integer factor n.
!   </DESCRIPTION>
!   <TEMPLATE>
!     time_scalar_mult(time, n)
!   </TEMPLATE>

!   <IN NAME="time" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <IN NAME="n" UNITS="" TYPE="integer" DIM="">
!      A time interval.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="time_type" DIM="" DEFAULT="">
!       Returns time multiplied by integer factor n.
!   </OUT>

function time_scalar_mult(time, n)

! Returns time multiplied by integer factor n

implicit none

type(time_type) :: time_scalar_mult
type(time_type), intent(in) :: time
integer, intent(in) :: n
integer(8) :: days, seconds
double precision :: sec_prod 

! Multiplying here in a reasonable fashion to avoid overflow is tricky
! Could multiply by some large factor n, and seconds could be up to 86399
! Need to avoid overflowing integers and wrapping around to negatives
sec_prod = dble(time%seconds) * dble(n)

! If sec_prod is large compared to precision of double precision, things
! can go bad.  Need to warn and abort on this.
if(sec_prod /= 0.0) then
   if(log10(sec_prod) > precision(sec_prod) - 3) call error_handler( &
      'Insufficient precision to handle scalar product in time_scalar_mult; contact developer')
end if

days = sec_prod / dble(24. * 60. * 60.)
seconds = sec_prod - dble(days) * dble(24. * 60. * 60.)

time_scalar_mult = set_time(seconds, time%days * n + days)

end function time_scalar_mult
! </FUNCTION>

!-------------------------------------------------------------------------
! <FUNCTION NAME="scalar_time_mult">

!   <OVERVIEW>
!       Returns time multiplied by integer factor n.
!   </OVERVIEW>
!   <DESCRIPTION>
!       Returns time multiplied by integer factor n.
!   </DESCRIPTION>
!   <TEMPLATE>
!     scalar_time_mult(n, time)
!   </TEMPLATE>

!   <IN NAME="time" UNITS="" TYPE="time_type" DIM="">A time interval.</IN>
!   <IN NAME="n" UNITS="" TYPE="integer" DIM=""> An integer. </IN>
!   <OUT NAME="" UNITS="" TYPE="time_type" DIM="" DEFAULT="">
!       Returns time multiplied by integer factor n.
!   </OUT>

function scalar_time_mult(n, time)

! Returns time multipled by integer factor n

implicit none

type(time_type) :: scalar_time_mult
type(time_type), intent(in) :: time
integer, intent(in) :: n

scalar_time_mult = time_scalar_mult(time, n)

end function scalar_time_mult
! </FUNCTION>

!-------------------------------------------------------------------------
! <FUNCTION NAME="time_divide">

!   <OVERVIEW>
!       Returns the largest integer, n, for which time1 >= time2 * n.
!   </OVERVIEW>
!   <DESCRIPTION>
!       Returns the largest integer, n, for which time1 >= time2 * n.
!   </DESCRIPTION>
!   <TEMPLATE>
!     time_divide(time1, time2)
!   </TEMPLATE>

!   <IN NAME="time1" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <IN NAME="time2" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="integer" DIM="" DEFAULT="">
!       Returns the largest integer, n, for which time1 >= time2 * n.
!   </OUT>

function time_divide(time1, time2)

! Returns the largest integer, n, for which time1 >= time2 * n.

implicit none

integer :: time_divide
type(time_type), intent(in) :: time1, time2
double precision :: d1, d2

! Convert time intervals to floating point days; risky for general performance?
d1 = time1%days * dble(60. * 60. * 24.) + dble(time1%seconds)
d2 = time2%days * dble(60. * 60. * 24.) + dble(time2%seconds) 

! Get integer quotient of this, check carefully to avoid round-off problems.
time_divide = d1 / d2

! Verify time_divide*time2 is <= time1 and (time_divide + 1)*time2 is > time1
if(time_divide * time2 > time1 .or. (time_divide + 1) * time2 <= time1) &
   call error_handler('time_divide quotient error :: notify developer')

end function time_divide
! </FUNCTION>

!-------------------------------------------------------------------------
! <FUNCTION NAME="time_real_divide">

!   <OVERVIEW>
!       Returns the double precision quotient of two times.
!   </OVERVIEW>
!   <DESCRIPTION>
!       Returns the double precision quotient of two times.
!   </DESCRIPTION>
!   <TEMPLATE>
!     time_real_divide(time1, time2)
!   </TEMPLATE>

!   <IN NAME="time1" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <IN NAME="time2" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="integer" DIM="double precision" DEFAULT="">
!       Returns the double precision quotient of two times
!   </OUT>

function time_real_divide(time1, time2)

! Returns the double precision quotient of two times

implicit none

double precision :: time_real_divide
type(time_type), intent(in) :: time1, time2
double precision :: d1, d2

! Convert time intervals to floating point days; risky for general performance?
d1 = time1%days * dble(60. * 60. * 24.) + dble(time1%seconds)
d2 = time2%days * dble(60. * 60. * 24.) + dble(time2%seconds) 

time_real_divide = d1 / d2

end function time_real_divide
! </FUNCTION>

!-------------------------------------------------------------------------
! <FUNCTION NAME="time_type_to_real">
!   <OVERVIEW>
!       Converts time to seconds and returns it as a real number
!   </OVERVIEW>
!   <DESCRIPTION>
!       Converts time to seconds and returns it as a real number
!   </DESCRIPTION>
!   <TEMPLATE>
!     time_type_to_real(time)
!   </TEMPLATE>
!   <IN NAME="time" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>

function time_type_to_real(time)

implicit none

double precision :: time_type_to_real
type(time_type), intent(in) :: time

time_type_to_real = dble(time%days) * 86400.d0 + dble(time%seconds)

end function time_type_to_real
! </FUNCTION>

!-------------------------------------------------------------------------
! <FUNCTION NAME="real_to_time_type">
!   <OVERVIEW>
!       Converts a real number of seconds to a time_type variable
!   </OVERVIEW>
!   <DESCRIPTION>
!       Converts a real number of seconds to a time_type variable
!   </DESCRIPTION>
!   <TEMPLATE>
!     real_to_time_type(x)
!   </TEMPLATE>
!   <IN NAME="x" UNITS="" TYPE="real" DIM="">
!      A real number of seconds
!   </IN>

function real_to_time_type(x)
type(time_type) :: real_to_time_type
real, intent(in) :: x
integer(8) :: seconds, days

days = floor(x/86400.)
seconds = int(x - 86400.*days)
real_to_time_type = set_time(seconds, days)

end function real_to_time_type
! </FUNCTION>

!-------------------------------------------------------------------------
! <FUNCTION NAME="time_scalar_divide">

!   <OVERVIEW>
!       Returns the largest time, t, for which n * t <= time.
!   </OVERVIEW>
!   <DESCRIPTION>
!       Returns the largest time, t, for which n * t <= time.
!   </DESCRIPTION>
!   <TEMPLATE>
!     time_scalar_divide(time, n)
!   </TEMPLATE>

!   <IN NAME="time" UNITS="" TYPE="time_type" DIM="">
!      A time interval.
!   </IN>
!   <IN NAME="n" UNITS="" TYPE="integer" DIM="">
!      An integer factor.
!   </IN>
!   <OUT NAME="" UNITS="" TYPE="integer" DIM="double precision" DEFAULT="">
!       Returns the largest time, t, for which n * t <= time.
!   </OUT>

function time_scalar_divide(time, n)

! Returns the largest time, t, for which n * t <= time

implicit none

type(time_type) :: time_scalar_divide
type(time_type), intent(in) :: time
integer, intent(in) :: n
double precision :: d, div
integer(8) :: days, seconds
type(time_type) :: prod1, prod2

! Convert time interval to floating point days; risky for general performance?
d = time%days * dble(60.*60.*24.) + dble(time%seconds)
div = d / dble(1.0 * n)

days = div / dble(60.*60.*24.)
seconds = div - days * dble(60.*60.*24.)
time_scalar_divide = set_time(seconds, days)

! Need to make sure that roundoff isn't killing this
prod1 = n * time_scalar_divide
prod2 = n * (increment_time(time_scalar_divide, 1, 0)) 
if(prod1 > time .or. prod2 <= time) &
   call error_handler('time_scalar_divide quotient error :: notify developer')

end function time_scalar_divide
! </FUNCTION>

!-------------------------------------------------------------------------
! <FUNCTION NAME="interval_alarm">

!   <OVERVIEW>
!     Given a time, and a time interval, this function returns true
!     if this is the closest time step to the alarm time. 
!   </OVERVIEW>
!   <DESCRIPTION>
!      This is a specialized operation that is frequently performed in models.
!      Given a time, and a time interval, this function is true if this is the
!      closest time step to the alarm time. The actual computation is:
! 
!             if((alarm_time - time) &#60;&#61; (time_interval / 2))
! 
!      If the function is true, the alarm time is incremented by the
!      alarm_interval; WARNING, this is a featured side effect. Otherwise, the
!      function is false and there are no other effects. CAUTION: if the
!      alarm_interval is smaller than the time_interval, the alarm may fail to
!      return true ever again.  Watch
!      for problems if the new alarm time is less than time + time_interval
!   </DESCRIPTION>
!   <TEMPLATE>
!      interval_alarm(time, time_interval, alarm, alarm_interval)
!   </TEMPLATE>

!   <IN NAME="time" TYPE="time_type"> Current time.  </IN>
!   <IN NAME="time_interval" TYPE="time_type"> A time interval.  </IN>
!   <IN NAME="alarm_interval" TYPE="time_type"> A time interval. </IN>
!   <OUT NAME="interval_alarm" TYPE="logical">
!     Returns either True or false.
!   </OUT>
!   <INOUT NAME="alarm" TYPE="time_type">
!     An alarm time, which is incremented by the alarm_interval
!                   if the function is true.
!   </INOUT>

function interval_alarm(time, time_interval, alarm, alarm_interval)

implicit none

! Supports a commonly used type of test on times for models.  Given the
! current time, and a time for an alarm, determines if this is the closest
! time to the alarm time given a time step of time_interval.  If this
! is the closest time (alarm - time <= time_interval/2), the function 
! returns true and the alarm is incremented by the alarm_interval.  Watch
! for problems if the new alarm time is less than time + time_interval

logical :: interval_alarm
type(time_type), intent(in) :: time, time_interval, alarm_interval
type(time_type), intent(inout) :: alarm

if((alarm - time) <= (time_interval / 2)) then
   interval_alarm = .TRUE.
   alarm = alarm + alarm_interval
else
   interval_alarm = .FALSE.
end if

end function interval_alarm
! </FUNCTION>

!--------------------------------------------------------------------------
! <FUNCTION NAME="repeat_alarm">

!   <OVERVIEW>
!      Repeat_alarm supports an alarm that goes off with
!      alarm_frequency and lasts for alarm_length. 
!   </OVERVIEW>
!   <DESCRIPTION>
!      Repeat_alarm supports an alarm that goes off with alarm_frequency and
!      lasts for alarm_length.  If the nearest occurence of an alarm time
!      is less than half an alarm_length from the input time, repeat_alarm
!      is true.  For instance, if the alarm_frequency is 1 day, and the 
!      alarm_length is 2 hours, then repeat_alarm is true from time 2300 on 
!      day n to time 0100 on day n + 1 for all n.
!   </DESCRIPTION>
!   <TEMPLATE>
!      repeat_alarm(time, alarm_frequency, alarm_length)
!   </TEMPLATE>

!   <IN NAME="time" TYPE="time_type"> Current time.  </IN>
!   <IN NAME="alarm_frequency" TYPE="time_type">
!     A time interval for alarm_frequency.
!   </IN>
!   <IN NAME="alarm_length" TYPE="time_type">
!     A time interval for alarm_length.
!   </IN>
!   <OUT NAME="repeat_alarm" TYPE="logical">
!     Returns either True or false.
!   </OUT>

function repeat_alarm(time, alarm_frequency, alarm_length)

implicit none

! Repeat_alarm supports an alarm that goes off with alarm_frequency and
! lasts for alarm_length.  If the nearest occurence of an alarm time
! is less than half an alarm_length from the input time, repeat_alarm
! is true.  For instance, if the alarm_frequency is 1 day, and the 
! alarm_length is 2 hours, then repeat_alarm is true from time 2300 on 
! day n to time 0100 on day n + 1 for all n.

logical :: repeat_alarm
type(time_type), intent(in) :: time, alarm_frequency, alarm_length
type(time_type) :: prev, next

prev = (time / alarm_frequency) * alarm_frequency
next = prev + alarm_frequency
if(time - prev <= alarm_length / 2 .or. next - time <= alarm_length / 2) then
   repeat_alarm = .TRUE.
else
   repeat_alarm = .FALSE.
endif

end function repeat_alarm
! </FUNCTION>

!--------------------------------------------------------------------------

!=========================================================================
! CALENDAR OPERATIONS BEGIN HERE
!=========================================================================

! <SUBROUTINE NAME="set_calendar_type">

!   <OVERVIEW>
!     Sets the default calendar type for mapping time intervals to dates.
!   </OVERVIEW>
!   <DESCRIPTION>
!     A constant number for setting the calendar type.
!   </DESCRIPTION>
!   <TEMPLATE> set_calendar_type(type) </TEMPLATE>

!   <IN NAME="type" TYPE="integer" DIM="" DEFAULT="">
!     A constant number for setting the calendar type.
!   </IN>
!   <OUT NAME="calendar_type" TYPE="integer">
!     A constant number for default calendar type.
!   </OUT>

!   <NOTE>
!     At present, four integer constants are defined for setting
!     the calendar type: THIRTY_DAY_MONTHS, JULIAN, NOLEAP, and
!     GREGORIAN. However, the GREGORIAN calendar is not completely
!     implemented. Selection of this type will result in illegal
!     type error.  The udunits library only supports
!     the JULIAN/GREGORIAN calendar types.  For more details on the
!     calendar used by udunits, see the "HANDLING TIME" section of the
!     fortran man page linked from the udunits home page,
!     <LINK SRC="http://www.unidata.ucar.edu/packages/udunits">http://www.unidata.ucar.edu/packages/udunits</LINK>.
!   </NOTE>

subroutine set_calendar_type(type)

! Selects calendar for default mapping from time to date. 

implicit none

integer, intent(in) :: type

! Do not check for initalization until all modules call the constructor of all used modules.
!if(.not.module_is_initialized) then
!  call error_mesg('set_calendar_type','time_manager_init has not been called',FATAL)
!endif

if(type <  0 .or. type > max_type) &
   call error_handler('Illegal calendar type passed to set_calendar_type')
calendar_type = type

if(type == GREGORIAN) &
   call error_handler('set_calendar_type :: GREGORIAN CALENDAR not implemented')

end subroutine set_calendar_type
! </SUBROUTINE>

!------------------------------------------------------------------------
! <FUNCTION NAME="get_calendar_type">

!   <OVERVIEW>
!      Returns the value of the default calendar type for mapping
!      from time to date.
!   </OVERVIEW>
!   <DESCRIPTION>
!     There are no arguments in this function. It returns the value of
!     the default calendar type for mapping from time to date.
!   </DESCRIPTION>
!   <TEMPLATE>
!     get_calendar_type()
!   </TEMPLATE>

function get_calendar_type()

! Returns default calendar type for mapping from time to date.

implicit none

integer :: get_calendar_type

get_calendar_type = calendar_type

end function get_calendar_type
! </FUNCTION>

!========================================================================
! START OF get_date BLOCK
! <SUBROUTINE NAME="get_date">

!   <OVERVIEW>
!      Given a time_interval, returns the corresponding date under
!      the selected calendar. 
!   </OVERVIEW>
!   <DESCRIPTION>
!      Given a time_interval, returns the corresponding date under
!      the selected calendar.
!   </DESCRIPTION>
!   <TEMPLATE>
!     get_date(time, year, month, day, hour, minute, second)
!   </TEMPLATE>
!   <IN NAME="time" TYPE="time_type"> A time interval.</IN>
!   <OUT NAME="day" TYPE="integer"></OUT>
!   <OUT NAME="month" TYPE="integer"></OUT>
!   <OUT NAME="year" TYPE="integer"></OUT>
!   <OUT NAME="second" TYPE="integer"></OUT>
!   <OUT NAME="minute" TYPE="integer"></OUT>
!   <OUT NAME="hour" TYPE="integer"></OUT>
!   <NOTE>
!     For all but the thirty_day_months calendar, increments to months
!     and years must be made separately from other units because of the
!     non-associative nature of the addition. All the input increments
!     must be positive.
!   </NOTE>
subroutine get_date(time, year, month, day, hour, minute, second)

! Given a time, computes the corresponding date given the selected calendar

implicit none

type(time_type), intent(in) :: time
integer(8), intent(out) :: second, minute, hour, day, month, year

select case(calendar_type)
case(THIRTY_DAY_MONTHS)
   call get_date_thirty(time, year, month, day, hour, minute, second)
case(GREGORIAN)
   call get_date_gregorian(time, year, month, day, hour, minute, second)
case(JULIAN)
   call get_date_julian(time, year, month, day, hour, minute, second)
case(NOLEAP)
   call get_date_no_leap(time, year, month, day, hour, minute, second)
case default
   call error_handler('Invalid calendar type in get_date')
end select
end subroutine get_date
! </SUBROUTINE>
!------------------------------------------------------------------------

subroutine get_date_gregorian(time, year, month, day, hour, minute, second)

! Computes date corresponding to time for gregorian calendar

implicit none

type(time_type), intent(in) :: time
integer(8), intent(out) :: second, minute, hour, day, month, year
integer :: m,t,nleapyr,nfh,nhund,nfour,nday
integer(8) :: dyear,dmonth,dday
integer(8), parameter :: secperday=86400,sixty=60
integer ndiy,nex,ibaseyr
logical :: leap

ibaseyr= 1601
! set nday initially to 109207 (the # of days from 1/1/1601 to 1/1/1900)
! 227 years of 365 days + 72 leap years
nday=109207
! time in seconds from base_year
t = time%seconds
nday=nday+t/(60*60*24)
! find number of four hundred year periods
nfh=nday/146097
nday=modulo(nday,146097)
! find number of hundred year periods
nhund= nday/36524
if(nhund.gt.3) then
  nhund=3
  nday=36524
else
  nday=modulo(nday,36524)
endif
! find number of four year periods
nfour=nday/1461
nday=modulo(nday,1461)
nex=nday/365
if(nex.gt.3) then
 nex=3
 nday=365
else
 nday=modulo(nday,365)
endif
! Is this a leap year? Gregorian calandar assigns each year evenly
! divisible by 4 that is not a century year unevenly divisible by 400
! as a leap-year. (i.e. 1700,1800,1900 are not leap-years, 2000 is)
leap=(nex.eq.3).and.((nfour.ne.24).or.(nhund.eq.3))
 if (leap) then
  ndiy=366
 else
  ndiy=365
 endif
year=INT(ibaseyr+400*nfh+100*nhund+4*nfour+nex,8)
nday=nday+1
! find month 
month=INT(0,8)
do m=1,12
 if (leap.and.(m.eq.2)) then
  if (nday.le. (days_per_month(2)+1)) then
   month = INT(m,8)
   go to 10
  else
   nday = nday - (days_per_month(2)+1)
   month = INT(m,8)
   t = t -  (secperday * (days_per_month(2)+1))
  endif
 else 
  if (nday.le. days_per_month(m)) then
   month = INT(m,8)
   go to 10
  else
   nday = nday - days_per_month(m)
   month = INT(m,8)
   t = t -  (secperday * days_per_month(month))
  endif
 endif
enddo
10 continue
! find day, hour,minute and second
dday = t / secperday
day = INT(nday,8)
t = t - dday * secperday
hour = INT(t,8) / (sixty * sixty)
t = t - hour * (sixty * sixty)
minute = INT(t,8) / sixty
second = INT(t,8) - sixty * minute
!if(leap) print*,'1:t,s,m,h,d,m,y=',time,second,minute,hour,day,month,year


end subroutine get_date_gregorian

!------------------------------------------------------------------------
function cut0(string)
character(len=256) :: cut0
character(len=*), intent(in) :: string
integer :: i

cut0 = string

do i=1,len(string)
  if(ichar(string(i:i)) == 0 ) then
    cut0(i:i) = ' '
  endif
enddo

return
end function cut0
!------------------------------------------------------------------------

subroutine get_date_julian(time, year, month, day, hour, minute, second)

! Base date for Julian calendar is year 1 with all multiples of 4 
! years being leap years.

implicit none

type(time_type), intent(in) :: time
integer(8), intent(out) :: second, minute, hour, day, month, year

integer :: m, t, nfour, nex, days_this_month
logical :: leap

! find number of four year periods; also get modulo number of days
nfour = time%days / (4 * 365 + 1) 
day = modulo(time%days, (4 * 365 + 1))

! Find out what year in four year chunk
nex = day / 365
if(nex == 4) then
   nex = 3
   day = 366
else
   day=modulo(day, 365) + 1
endif

! Is this a leap year? 
leap = (nex == 3)

year = 1 + 4 * nfour + nex

! find month and day
do m = 1, 12
   month = m
   days_this_month = days_per_month(m)
   if(leap .and. m == 2) days_this_month = 29
   if(day <= days_this_month) exit
   day = day - days_this_month
end do

! find hour,minute and second
t = time%seconds
hour = t / (60 * 60)
t = t - hour * (60 * 60)
minute = t / 60
second = t - 60 * minute

end subroutine get_date_julian

!------------------------------------------------------------------------

subroutine get_date_thirty(time, year, month, day, hour, minute, second)

! Computes date corresponding to time interval for 30 day months, 12
! month years.

implicit none

type(time_type), intent(in) :: time
integer(8), intent(out) :: second, minute, hour, day, month, year
integer :: t, dmonth, dyear

t = time%days
dyear = t / (30 * 12)
year = dyear + 1
t = t - dyear * (30 * 12)
dmonth = t / 30
month = 1 + dmonth
day = t -dmonth * 30 + 1

t = time%seconds
hour = t / (60 * 60) 
t = t - hour * (60 * 60)
minute = t / 60
second = t - 60 * minute

end subroutine get_date_thirty
!------------------------------------------------------------------------

subroutine get_date_no_leap(time, year, month, day, hour, minute, second)

! Base date for NOLEAP calendar is year 1.

implicit none

type(time_type), intent(in) :: time
integer(8), intent(out) :: second, minute, hour, day, month, year
integer :: m, t

! get modulo number of days
year = time%days / 365 + 1
day = modulo(time%days, 365) + 1

! find month and day
do m = 1, 12
   month = m
   if(day <= days_per_month(m)) exit
   day = day - days_per_month(m)
end do

! find hour,minute and second
t = time%seconds
hour = t / (60 * 60)
t = t - hour * (60 * 60)
minute = t / 60
second = t - 60 * minute

end subroutine get_date_no_leap

! END OF get_date BLOCK
!========================================================================
! START OF set_date BLOCK
! <FUNCTION NAME="set_date">

!   <OVERVIEW>
!      Given an input date in year, month, days, etc., creates a
!      time_type that represents this time interval from the
!      internally defined base date.
!   </OVERVIEW>
!   <DESCRIPTION>
!      Given a date, computes the corresponding time given the selected
!      date time mapping algorithm. Note that it is possible to specify
!      any number of illegal dates; these should be checked for and generate
!      errors as appropriate.
!   </DESCRIPTION>
!   <TEMPLATE>
!      set_date(year, month, day, hours, minutes, seconds)
!   </TEMPLATE>
!   <IN NAME="time" TYPE="time_type"> A time interval.</IN>
!   <IN NAME="day" TYPE="integer"></IN>
!   <IN NAME="month" TYPE="integer"></IN>
!   <IN NAME="year" TYPE="integer"></IN>
!   <IN NAME="second" TYPE="integer"></IN>
!   <IN NAME="minute" TYPE="integer"></IN>
!   <IN NAME="hour" TYPE="integer"></IN>
!   <OUT NAME="set_date" TYPE="time_type"> A time interval.</OUT>

function set_date_i(year, month, day, hours, minutes, seconds)

! Given a date, computes the corresponding time given the selected
! date time mapping algorithm.  Note that it is possible to specify
! any number of illegal dates; these should be checked for and generate
! errors as appropriate.

implicit none

type(time_type) :: set_date_i
integer(8), intent(in) :: day, month, year
integer(8), intent(in), optional :: seconds, minutes, hours
integer(8) :: oseconds, ominutes, ohours
integer(8),parameter :: zero=0

! Missing optionals are set to 0
oseconds = zero; if(present(seconds)) oseconds = seconds
ominutes = zero; if(present(minutes)) ominutes = minutes
ohours = zero; if(present(hours)) ohours = hours

select case(calendar_type)
case(THIRTY_DAY_MONTHS)
   set_date_i = set_date_thirty(year, month, day, ohours, ominutes, oseconds)
case(GREGORIAN)
   set_date_i = set_date_gregorian(year, month, day, ohours, ominutes, oseconds)
case(JULIAN)
   set_date_i = set_date_julian(year, month, day, ohours, ominutes, oseconds)
case(NOLEAP)
   set_date_i = set_date_no_leap(year, month, day, ohours, ominutes, oseconds)
case (NO_CALENDAR)
   call error_mesg('set_date_i','Cannot compute a date when calendar type=NO_CALENDAR',FATAL)
case default
   call error_mesg('set_date_i','Invalid calendar type.',FATAL)
end select
end function set_date_i
! </FUNCTION>

!------------------------------------------------------------------------

function set_date_c(string)

! Examples of acceptable forms of string:

! 1980-01-01 00:00:00
! 1980-1-1 0:0:0
! 1980-1-1

! year number must occupy 4 spaces.
! months, days, hours, minutes, seconds may occupy 1 or 2 spaces
! year, month and day must be separated by a '-'
! hour, minute, second must be separated by a ':'
! hour, minute, second are optional. If not present then zero is assumed.

implicit none

type(time_type) :: set_date_c
character(len=*), intent(in) :: string
character(len=4) :: formt='(i )'
logical :: correct_form
integer :: i1, i2, i3, i4, i5, i6
character(len=32) :: string_sifted_left
integer(8) :: year, month, day, hour, minute, second

string_sifted_left = adjustl(string)
i1 = index(string_sifted_left,'-')
i2 = index(string_sifted_left,'-',back=.true.)
i3 = index(string_sifted_left,':')
i4 = index(string_sifted_left,':',back=.true.)
i5 = len_trim(cut0(string_sifted_left))
i6 = index(string_sifted_left,'.',back=.true.)
if(i6==i4+2 .or. i6==i4+3) i5=i6-1  ! if fraction second is present, truncate
correct_form = (i1 == 5) ! year number must occupy 4 spaces
correct_form = (i2-i1 == 2 .or. i2-i1 == 3) ! month number must occupy 1 or 2 spaces
correct_form = correct_form .and. (i5 == i2+1 .or. i5 == i2+2 .or. i5 == i4+1 .or. i5 == i4+2) ! end of string must be either day number or seconds
correct_form = correct_form .and. (i3 == 0 .or. (i4-i3 == 2 .or. i4-i3 == 3)) ! if minute number exists, it must occupy 1 or 2 spaces
if(.not.correct_form) then
  call error_mesg('set_date_c','Form of character time stamp is incorrect.'// &
  ' It must be in the form: year-month-day or year-month-day hr:min:sec'// &
  ' The character time stamp is: '//trim(string),FATAL)
endif
read(string_sifted_left(1:4),'(i4)') year
if(year == 0) then
  year = 1
  if(zero_year_warning) then
    call error_mesg('set_date_c','Year zero is invalid when a calendar is in effect. Resetting year to 1', WARNING)
  endif
endif
write(formt(3:3),'(i1)') i2-i1-1
read(string_sifted_left(i1+1:i2-1),formt) month
i6 = min(i2+2,i5)
read(string_sifted_left(i2+1:i6),'(i2)') day
if(i3 == 0) then
  hour = 0
  minute = 0
  second = 0
else
  read(string_sifted_left(i3-2:i3-1),'(i2)') hour
  write(formt(3:3),'(i1)') i4-i3-1
  read(string_sifted_left(i3+1:i4-1),formt) minute
  write(formt(3:3),'(i1)') i5-i4
  read(string_sifted_left(i4+1:i5  ),formt) second
endif
set_date_c = set_date(year, month, day, hour, minute, second)

end function set_date_c
!------------------------------------------------------------------------

function set_date_gregorian(year, month, day, hours, minutes, seconds)

! Computes time corresponding to date for gregorian calendar.

implicit none

type(time_type) :: set_date_gregorian
integer(8), intent(in) :: day, month, year
integer(8), intent(in), optional :: seconds, minutes, hours
integer(8) :: oseconds, ominutes, ohours
integer days, m, nleapyr
integer :: base_year = 1900
logical :: leap
integer(8),parameter :: zero=0

! Missing optionals are set to 0
oseconds = zero; if(present(seconds)) oseconds = seconds
ominutes = zero; if(present(minutes)) ominutes = minutes
ohours = zero; if(present(hours)) ohours = hours

! Need to check for bogus dates
if(oseconds .gt. 59 .or. oseconds .lt. zero .or. ominutes .gt. 59 .or. ominutes .lt. zero &
   .or. ohours .gt. 23 .or. ohours .lt. zero .or. day .gt. 31 .or. day .lt. 1 &
        .or. month .gt. 12 .or. month .lt. 1 .or. year .lt. base_year) &
      call error_handler('Invalid date in set_date_gregorian')

! Is this a leap year? Gregorian calandar assigns each year evenly
! divisible by 4 that is not a century year unevenly divisible by 400
! as a leap-year. (i.e. 1700,1800,1900 are not leap-years, 2000 is)
  leap=(modulo(year,4).eq.0)
  if((modulo(year,100).eq.0).and.(modulo(year,400).ne.0))then
   leap=.false.
  endif
! compute number of leap years from base_year
nleapyr=((year-1)-base_year)/4-((year-1)-base_year)/100+((year-1)-1600)/400
days = 0
do m=1,month-1
 days = days + days_per_month(m)
 if(leap.and.m.eq.2)days=days+1
enddo
set_date_gregorian%seconds = oseconds + 60*(ominutes + 60*(ohours + 24*((day - 1) + &
        (days + 365*(year - base_year-nleapyr)+366*(nleapyr)))))

end function set_date_gregorian

!------------------------------------------------------------------------

function set_date_julian(year, month, day, hours, minutes, seconds)

! Returns time corresponding to date for julian calendar.

implicit none

type(time_type) :: set_date_julian
integer(8), intent(in) :: day, month, year
integer(8), intent(in), optional :: seconds, minutes, hours
integer(8) :: oseconds, ominutes, ohours
integer ndays, m, nleapyr
logical :: leap
character(len=36) :: chdate
integer(8),parameter :: zero=0

! Missing optionals are set to 0
oseconds = zero; if(present(seconds)) oseconds = seconds
ominutes = zero; if(present(minutes)) ominutes = minutes
ohours = zero; if(present(hours)) ohours = hours

! Need to check for bogus dates
if(oseconds > 59 .or. oseconds < zero .or. ominutes > 59 .or. ominutes < zero &
   .or. ohours > 23 .or. ohours < zero .or. day < 1 &
   .or. month > 12 .or. month < 1 .or. year < 1) then
   write(chdate,'(6i6)') year,month,day,ohours,ominutes,oseconds
   call error_handler('Invalid date in set_date_julian. Date='//chdate)
endif
if(month /= 2 .and. day > days_per_month(month)) &
   call error_handler('Invalid day in set_date_julian')

! Is this a leap year? 
leap = (modulo(year,4) == 0)
! compute number of complete leap years from year 1
nleapyr = (year - 1) / 4

! Finish checking for day specication errors
if(month == 2 .and. (day > 29 .or. ((.not. leap) .and. day > 28))) &
   call error_handler('Invalid number of days in month 2 in set_date_julian')

ndays = 0
do m = 1, month - 1
   ndays = ndays + days_per_month(m)
   if(leap .and. m == 2) ndays = ndays + 1
enddo

set_date_julian%seconds = oseconds + 60 * (ominutes + 60 * ohours)
set_date_julian%days = day -1 + ndays + 365*(year - nleapyr - 1) + 366*(nleapyr)
end function set_date_julian

!------------------------------------------------------------------------

function set_date_thirty(year, month, day, hours, minutes, seconds)

! Computes time corresponding to date for thirty day months.

implicit none

type(time_type) :: set_date_thirty
integer(8), intent(in) :: day, month, year
integer(8), intent(in), optional :: seconds, minutes, hours
integer(8) :: oseconds, ominutes, ohours
integer(8),parameter :: zero=0

! Missing optionals are set to 0
oseconds = zero; if(present(seconds)) oseconds = seconds
ominutes = zero; if(present(minutes)) ominutes = minutes
ohours = zero; if(present(hours)) ohours = hours

! Need to check for bogus dates
if(oseconds > 59 .or. oseconds < 0 .or. ominutes > 59 .or. ominutes < 0 &
   .or. ohours > 23 .or. ohours < 0 .or. day > 30 .or. day < 1 &
   .or. month > 12 .or. month < 1 .or. year < 1) &
      call error_handler('Invalid date in set_date_thirty')

set_date_thirty%days = (day - 1) + 30 * ((month - 1) + 12 * (year - 1))
set_date_thirty%seconds = oseconds + 60 * (ominutes + 60 * ohours)

end function set_date_thirty

!------------------------------------------------------------------------

function set_date_no_leap(year, month, day, hours, minutes, seconds)

! Computes time corresponding to date for fixed 365 day year calendar.

implicit none

type(time_type) :: set_date_no_leap
integer(8), intent(in) :: day, month, year
integer(8), intent(in), optional :: seconds, minutes, hours
integer(8) :: oseconds, ominutes, ohours
integer(8) :: ndays, days_in
integer :: m
integer(8),parameter :: zero=0

! Missing optionals are set to 0
oseconds = zero; if(present(seconds)) oseconds = seconds
ominutes = zero; if(present(minutes)) ominutes = minutes
ohours = zero; if(present(hours)) ohours = hours

! Need to check for bogus dates
if(oseconds > 59 .or. oseconds < 0 .or. ominutes > 59 .or. ominutes < 0 &
   .or. ohours > 23 .or. ohours < 0 .or. day > 31 .or. day < 1 &
   .or. month > 12 .or. month < 1 .or. year < 1) then
   call error_handler('Invalid date in set_date_no_leap')
endif

if(day > days_per_month(month)) call error_handler('Invalid day in set_date_no_leap')

ndays = 0
do m = 1, month - 1
   ndays = ndays + INT(days_per_month(m),8)
enddo
days_in = INT(day,8) -INT(1,8) + ndays + INT(365,8) * (INT(year,8) - INT(1,8))
set_date_no_leap = set_time(oseconds + INT(60,8) * (ominutes + INT(60,8) * ohours), &
   days_in )

end function set_date_no_leap

! END OF set_date BLOCK
!=========================================================================
! START OF increment_date BLOCK
! <FUNCTION NAME="increment_date">

!   <OVERVIEW>
!      Increments the date represented by a time interval and the
!      default calendar type by a number of seconds, etc. 
!   </OVERVIEW>
!   <DESCRIPTION>
!      Given a time and some date increment, computes a new time.  Depending
!      on the mapping algorithm from date to time, it may be possible to specify
!      undefined increments (i.e. if one increments by 68 days and 3 months in
!      a Julian calendar, it matters which order these operations are done and
!      we don't want to deal with stuff like that, make it an error).
!   </DESCRIPTION>
!   <TEMPLATE>
!      increment_date(time, years, months, days, hours, minutes, seconds)
!   </TEMPLATE>
!   <IN NAME="time" TYPE="time_type"> A time interval.</IN>
!   <IN NAME="day" TYPE="integer">An increment of days.</IN>
!   <IN NAME="month" TYPE="integer">An increment of months.</IN>
!   <IN NAME="year" TYPE="integer">An increment of years.</IN>
!   <IN NAME="second" TYPE="integer">An increment of seconds.</IN>
!   <IN NAME="minute" TYPE="integer">An increment of minutes.</IN>
!   <IN NAME="hour" TYPE="integer">An increment of hours.</IN>
!   <OUT NAME="increment_date" TYPE="time_type"> A new time based on the input 
!         time interval and the default calendar type.
!   </OUT>

function increment_date(time, years, months, days, hours, minutes, seconds)

! Given a time and some date increment, computes a new time.  Depending
! on the mapping algorithm from date to time, it may be possible to specify
! undefined increments (i.e. if one increments by 68 days and 3 months in
! a Julian calendar, it matters which order these operations are done and
! we don't want to deal with stuff like that, make it an error).

implicit none

type(time_type) :: increment_date
type(time_type), intent(in) :: time
integer, intent(in), optional :: seconds, minutes, hours, days, months, years
integer :: oseconds, ominutes, ohours, odays, omonths, oyears

! Missing optionals are set to 0
oseconds = 0; if(present(seconds)) oseconds = seconds
ominutes = 0; if(present(minutes)) ominutes = minutes
ohours = 0; if(present(hours)) ohours = hours
odays = 0; if(present(days)) odays = days
omonths = 0; if(present(months)) omonths = months
oyears = 0; if(present(years)) oyears = years

select case(calendar_type)
case(THIRTY_DAY_MONTHS)
   increment_date = increment_thirty(time, oyears, omonths, odays, ohours, ominutes, oseconds)
case(GREGORIAN)
   increment_date = increment_gregorian(time, oyears, omonths, odays, ohours, ominutes, oseconds)
case(JULIAN)
   increment_date = increment_julian(time, oyears, omonths, odays, ohours, ominutes, oseconds)
case(NOLEAP)
   increment_date = increment_no_leap(time, oyears, omonths, odays, ohours, ominutes, oseconds)
case default
   call error_handler('Invalid calendar type in increment_date')
end select
end function increment_date
! </FUNCTION>

!-------------------------------------------------------------------------

function increment_gregorian(time, years, months, days, hours, minutes, seconds)

! Given time and some date increment, computes new time for gregorian calendar.

implicit none

type(time_type) :: increment_gregorian
type(time_type), intent(in) :: time
integer(8), intent(in), optional :: seconds, minutes, hours, days, months, years
integer(8) :: oseconds, ominutes, ohours, odays, omonths, oyears
integer(8) :: csecond, cminute, chour, cday, cmonth, cyear
integer(8), parameter :: zero=0

call error_handler('increment_gregorian not implemented')

! Missing optionals are set to 0
oseconds = zero; if(present(seconds)) oseconds = seconds
ominutes = zero; if(present(minutes)) ominutes = minutes
ohours = zero; if(present(hours)) ohours = hours
odays = zero; if(present(days)) odays = days
omonths = zero; if(present(months)) omonths = months
oyears = zero; if(present(years)) oyears = years

! Increment must be positive definite
if(oseconds < zero .or. ominutes < zero .or. ohours < zero .or. odays < zero .or. omonths < zero .or. &
   oyears < zero) call error_handler('Illegal increment in increment_gregorian')

! First convert time into date
call get_date_gregorian(time, cyear, cmonth, cday, chour, cminute, csecond)

! Add on the increments
csecond = csecond + oseconds
cminute = cminute + ominutes
chour = chour + ohours
cday = cday + odays
cmonth = cmonth + omonths
cyear = cyear + oyears

! Convert this back into a time
increment_gregorian = set_date_gregorian(cyear, cmonth, cday, chour, cminute, csecond)
end function increment_gregorian

!-------------------------------------------------------------------------

function increment_julian(time, years, months, days, hours, minutes, seconds)

! Given time and some date increment, computes new time for julian calendar.

implicit none

type(time_type) :: increment_julian
type(time_type), intent(in) :: time
integer(8), intent(in), optional :: seconds, minutes, hours, days, months, years
integer(8) :: oseconds, ominutes, ohours, odays, omonths, oyears
integer(8) :: csecond, cminute, chour, cday, cmonth, cyear, dyear
type(time_type) :: t
integer(8),parameter :: zero=0,twelve=12
integer(8) :: daysinmonth

! Missing optionals are set to 0
oseconds = zero; if(present(seconds)) oseconds = seconds
ominutes = zero; if(present(minutes)) ominutes = minutes
ohours = zero; if(present(hours)) ohours = hours
odays = zero; if(present(days)) odays = days
omonths = zero; if(present(months)) omonths = months
oyears = zero; if(present(years)) oyears = years

! Increment must be positive definite
if(oseconds < zero .or. ominutes < zero .or. ohours < zero .or. odays < zero .or. &
   omonths < zero .or. oyears < zero) &
   call error_handler('Illegal increment in increment_julian')

!  There are a number of other bad types of increments that should be
!  prohibited here; the addition is not associative
!  Easiest thing is to only let month and year be incremented by themselves
!  This is slight overkill since year is not really a problem.
if(omonths /= zero .and. (oseconds /= zero .or. ominutes /= zero .or. ohours /= zero .or. &
   odays /= zero .or. oyears /= zero)) call error_handler &
   ('increment_julian: month must not be incremented with other units')
if(oyears /= zero .and. (oseconds /= zero .or. ominutes /= zero .or. ohours /= zero .or. &
   odays /= zero .or. omonths /= zero)) call error_handler &
   ('increment_julian: year must not be incremented with other units')

!  For non-month and non-year part can just use increment_thirty
t =  increment_thirty(time, zero, zero, odays, ohours, ominutes, oseconds)

!  For month or year increment, first convert to date
call get_date_julian(t, cyear, cmonth, cday, chour, cminute, csecond)
cmonth = cmonth + omonths
cyear = cyear + oyears
! Check for months larger than 12 and fix
if(cmonth > twelve) then
   dyear = (cmonth - INT(1,8)) / twelve 
   cmonth = cmonth - twelve * dyear
   cyear = cyear + dyear
end if
!mj Check for months with less days than initial month
daysinmonth = days_per_month(cmonth)
if(((cyear / 4 * 4) == cyear) .and. cmonth == 2) daysinmonth = 29
cday = min(cday,daysinmonth)
   
! Convert this back into a time
increment_julian = set_date_julian(cyear, cmonth, cday, chour, cminute, csecond)

end function increment_julian

!-------------------------------------------------------------------------

function increment_thirty(time, years, months, days, hours, minutes, seconds)

! Given a time and some date increment, computes new time for thirty day months.

implicit none

type(time_type) :: increment_thirty
type(time_type), intent(in) :: time
integer(8), intent(in), optional :: seconds, minutes, hours, days, months, years
integer(8) :: oseconds, ominutes, ohours, odays, omonths, oyears
integer(8) :: csecond, cday
integer(8),parameter :: zero=0,twelve=12,thirty=30,sixty=60

! Missing optionals are set to 0
oseconds = zero; if(present(seconds)) oseconds = seconds
ominutes = zero; if(present(minutes)) ominutes = minutes
ohours = zero; if(present(hours)) ohours = hours
odays = zero; if(present(days)) odays = days
omonths = zero; if(present(months)) omonths = months
oyears = zero; if(present(years)) oyears = years

! Increment must be positive definite
if(oseconds < zero .or. ominutes < zero .or. ohours < zero .or. odays < zero .or. &
   omonths < zero .or. oyears < zero) &
   call error_handler('Illegal increment in increment_thirty')

! Do increment to seconds portion first
csecond = oseconds + sixty * (ominutes + sixty * ohours)
cday = odays + thirty * (omonths + twelve * oyears)
increment_thirty = increment_time(time, csecond, cday)

end function increment_thirty
!-------------------------------------------------------------------------

function increment_no_leap(time, years, months, days, hours, minutes, seconds)

! Given time and some date increment, computes new time for julian calendar.

implicit none

type(time_type) :: increment_no_leap
type(time_type), intent(in) :: time
integer(8), intent(in), optional :: seconds, minutes, hours, days, months, years
integer(8) :: oseconds, ominutes, ohours, odays, omonths, oyears
integer(8) :: csecond, cminute, chour, cday, cmonth, cyear, dyear
type(time_type) :: t
integer(8),parameter :: zero=0,twelve=12

! Missing optionals are set to 0
oseconds = zero; if(present(seconds)) oseconds = seconds
ominutes = zero; if(present(minutes)) ominutes = minutes
ohours = zero; if(present(hours)) ohours = hours
odays = zero; if(present(days)) odays = days
omonths = zero; if(present(months)) omonths = months
oyears = zero; if(present(years)) oyears = years

! Increment must be positive definite
if(oseconds < zero .or. ominutes < zero .or. ohours < zero .or. odays < zero .or. &
   omonths < zero .or. oyears < zero) &
   call error_handler('Illegal increment in increment_no_leap')

!  There are a number of other bad types of increments that should be
!  prohibited here; the addition is not associative
!  Easiest thing is to only let month and year be incremented by themselves
!  This is slight overkill since year is not really a problem.
if(omonths /= zero .and. (oseconds /= zero .or. ominutes /= zero .or. ohours /= zero .or. &
   odays /= zero .or. oyears /= zero)) call error_handler &
   ('increment_no_leap: month must not be incremented with other units')
if(oyears /= zero .and. (oseconds /= zero .or. ominutes /= zero .or. ohours /= zero .or. &
   odays /= zero .or. omonths /= zero)) call error_handler &
   ('increment_no_leap: year must not be incremented with other units')

!  For non-month and non-year part can just use increment_thirty
t =  increment_thirty(time, zero, zero, odays, ohours, ominutes, oseconds)

!  For month or year increment, first convert to date
call get_date_no_leap(t, cyear, cmonth, cday, chour, cminute, csecond)
cmonth = cmonth + omonths
cyear = cyear + oyears
! Check for months larger than 12 and fix
if(cmonth > twelve) then
   dyear = (cmonth - INT(1,8)) / twelve 
   cmonth = cmonth - twelve * dyear
   cyear = cyear + dyear
end if

! Convert this back into a time
increment_no_leap = set_date_no_leap(cyear, cmonth, cday, chour, cminute, csecond)

end function increment_no_leap

! END OF increment_date BLOCK
!=========================================================================
! START OF decrement_date BLOCK
! <FUNCTION NAME="decrement_date">

!   <OVERVIEW>
!      Decrements the date represented by a time interval and the
!      default calendar type by a number of seconds, etc. 
!   </OVERVIEW>
!   <DESCRIPTION>
!      Given a time and some date decrement, computes a new time.  Depending
!      on the mapping algorithm from date to time, it may be possible to specify
!      undefined decrements (i.e. if one decrements by 68 days and 3 months in
!      a Julian calendar, it matters which order these operations are done and
!      we don't want to deal with stuff like that, make it an error).
!   </DESCRIPTION>
!   <TEMPLATE>
!      decrement_date(time, years, months, days, hours, minutes, seconds)
!   </TEMPLATE>
!   <IN NAME="time" TYPE="time_type"> A time interval.</IN>
!   <IN NAME="day" TYPE="integer">A decrement of days.</IN>
!   <IN NAME="month" TYPE="integer">A deincrement of months.</IN>
!   <IN NAME="year" TYPE="integer">A deincrement of years.</IN>
!   <IN NAME="second" TYPE="integer">A deincrement of seconds.</IN>
!   <IN NAME="minute" TYPE="integer">A deincrement of minutes.</IN>
!   <IN NAME="hour" TYPE="integer">A deincrement of hours.</IN>
!   <OUT NAME="decrement_date" TYPE="time_type"> A new time based on the input 
!         time interval and the default calendar type.
!   </OUT>
!   <NOTE>
!     For all but the thirty_day_months calendar, decrements to months
!     and years must be made separately from other units because of the
!     non-associative nature of addition. All the input decrements must
!     be positive. If the result is a negative time (i.e. date before the
!     base date) it is considered a fatal error.
!   </NOTE>

function decrement_date(time, years, months, days, hours, minutes, seconds)

! Given a time and some date decrement, computes a new time.  Depending
! on the mapping algorithm from date to time, it may be possible to specify
! undefined decrements (i.e. if one decrements by 68 days and 3 months in
! a Julian calendar, it matters which order these operations are done and
! we don't want to deal with stuff like that, make it an error).

implicit none

type(time_type) :: decrement_date
type(time_type), intent(in) :: time
integer(8), intent(in), optional :: seconds, minutes, hours, days, months, years
integer(8) :: oseconds, ominutes, ohours, odays, omonths, oyears
integer(8),parameter :: zero=0

! Missing optionals are set to 0
oseconds = zero; if(present(seconds)) oseconds = seconds
ominutes = zero; if(present(minutes)) ominutes = minutes
ohours = zero; if(present(hours)) ohours = hours
odays = zero; if(present(days)) odays = days
omonths = zero; if(present(months)) omonths = months
oyears = zero; if(present(years)) oyears = years

select case(calendar_type)
case(THIRTY_DAY_MONTHS)
   decrement_date = decrement_thirty(time, oyears, omonths, odays, ohours, ominutes, oseconds)
case(GREGORIAN)
   decrement_date = decrement_gregorian(time, oyears, omonths, odays, ohours, ominutes, oseconds)
case(JULIAN)
   decrement_date = decrement_julian(time, oyears, omonths, odays, ohours, ominutes, oseconds)
case(NOLEAP)
   decrement_date = decrement_no_leap(time, oyears, omonths, odays, ohours, ominutes, oseconds)
case default
   call error_handler('Invalid calendar type in decrement_date')
end select

end function decrement_date
! </FUNCTION>

!-------------------------------------------------------------------------

function decrement_gregorian(time, years, months, days, hours, minutes, seconds)

! Given time and some date decrement, computes new time for gregorian calendar.

implicit none

type(time_type) :: decrement_gregorian
type(time_type), intent(in) :: time
integer(8), intent(in), optional :: seconds, minutes, hours, days, months, years
integer(8) :: oseconds, ominutes, ohours, odays, omonths, oyears
integer(8) :: csecond, cminute, chour, cday, cmonth, cyear
integer(8),parameter :: zero=0

call error_handler('decrement_gregorian not implemented')
! Missing optionals are set to 0
oseconds = zero; if(present(seconds)) oseconds = seconds
ominutes = zero; if(present(minutes)) ominutes = minutes
ohours = zero; if(present(hours)) ohours = hours
odays = zero; if(present(days)) odays = days
omonths = zero; if(present(months)) omonths = months
oyears = zero; if(present(years)) oyears = years


! Decrement must be positive definite
if(oseconds < zero .or. ominutes < zero .or. ohours < zero .or. odays < zero .or. omonths < zero .or. &
   oyears < zero) call error_handler('Illegal decrement in decrement_gregorian')

! First convert time into date
call get_date_gregorian(time, cyear, cmonth, cday, chour, cminute, csecond)

! Remove the increments
csecond = csecond - oseconds
cminute = cminute - ominutes
chour = chour - ohours
cday = cday - odays
cmonth = cmonth - omonths
cyear = cyear - oyears

! Convert this back into a time
decrement_gregorian =  set_date_gregorian(cyear, cmonth, cday, chour, cminute, csecond)

end function decrement_gregorian

!-------------------------------------------------------------------------

function decrement_julian(time, years, months, days, hours, minutes, seconds)

! Given time and some date decrement, computes new time for julian calendar.

implicit none

type(time_type) :: decrement_julian
type(time_type), intent(in) :: time
integer(8), intent(in), optional :: seconds, minutes, hours, days, months, years
integer(8) :: oseconds, ominutes, ohours, odays, omonths, oyears
integer(8) :: csecond, cminute, chour, cday, cmonth, cyear
type(time_type) :: t
integer(8),parameter :: zero=0

! Missing optionals are set to 0
oseconds = zero; if(present(seconds)) oseconds = seconds
ominutes = zero; if(present(minutes)) ominutes = minutes
ohours = zero; if(present(hours)) ohours = hours
odays = zero; if(present(days)) odays = days
omonths = zero; if(present(months)) omonths = months
oyears = zero; if(present(years)) oyears = years

! Increment must be positive definite
if(oseconds < zero .or. ominutes < zero .or. ohours < zero .or. odays < zero .or. &
   omonths < zero .or. oyears < zero) &
   call error_handler('Illegal increment in decrement_julian')

!  There are a number of other bad types of decrements that should be
!  prohibited here; the subtraction is not associative
!  Easiest thing is to only let month and year be decremented by themselves
!  This is slight overkill since year is not really a problem.
if(omonths /= zero .and. (oseconds /= zero .or. ominutes /= zero .or. ohours /= zero .or. &
   odays /= zero .or. oyears /= zero)) call error_handler &
   ('decrement_julian: month must not be decremented with other units')
if(oyears /= zero .and. (oseconds /= zero .or. ominutes /= zero .or. ohours /= zero .or. &
   odays /= zero .or. omonths /= zero)) call error_handler &
   ('decrement_julian: year must not be decremented with other units')

!  For non-month and non-year can just use decrement_thirty
t = decrement_thirty(time, zero, zero, odays, ohours, ominutes, oseconds)

!  For month or year decrement, first convert to date
call get_date_julian(t, cyear, cmonth, cday, chour, cminute, csecond)
cmonth = cmonth - omonths
cyear = cyear - oyears

! Check for months less than 12 and fix
if(cmonth < 1) then
   cyear = cyear - 1 + (cmonth) / 12
   cmonth = cmonth - 12 * ( -1 + (cmonth) / 12)
end if

! Check for negative years
if(cyear < 1) call error_handler('Illegal date results in decrement_julian')

! Convert this back into a time
decrement_julian = set_date_julian(cyear, cmonth, cday, chour, cminute, csecond)

end function decrement_julian

!-------------------------------------------------------------------------

function decrement_thirty(time, years, months, days, hours, minutes, seconds)

! Given a time and some date decrement, computes new time for thirty day months.

implicit none

type(time_type) :: decrement_thirty
type(time_type), intent(in) :: time
integer(8), intent(in), optional :: seconds, minutes, hours, days, months, years
integer(8) :: oseconds, ominutes, ohours, odays, omonths, oyears
integer(8) :: csecond, cday
integer(8),parameter :: zero=0,twelve=12,thirty=30,sixty=60

! Missing optionals are set to 0
oseconds = zero; if(present(seconds)) oseconds = seconds
ominutes = zero; if(present(minutes)) ominutes = minutes
ohours = zero; if(present(hours)) ohours = hours
odays = zero; if(present(days)) odays = days
omonths = zero; if(present(months)) omonths = months
oyears = zero; if(present(years)) oyears = years


! Increment must be positive definite
if(oseconds < zero .or. ominutes < zero .or. ohours < zero .or. odays < zero .or. &
   omonths < zero .or. oyears < zero) &
   call error_handler('Illegal decrement in decrement_thirty')

csecond = oseconds + sixty * (ominutes + sixty * ohours)
cday = odays + thirty * (omonths + twelve * oyears)
decrement_thirty = decrement_time(time, csecond, cday)

end function decrement_thirty

!-------------------------------------------------------------------------

function decrement_no_leap(time, years, months, days, hours, minutes, seconds)

! Given time and some date decrement, computes new time for julian calendar.

implicit none

type(time_type) :: decrement_no_leap
type(time_type), intent(in) :: time
integer(8), intent(in), optional :: seconds, minutes, hours, days, months, years
integer(8) :: oseconds, ominutes, ohours, odays, omonths, oyears
integer(8) :: csecond, cminute, chour, cday, cmonth, cyear
type(time_type) :: t
integer(8),parameter :: zero=0

! Missing optionals are set to 0
oseconds = zero; if(present(seconds)) oseconds = seconds
ominutes = zero; if(present(minutes)) ominutes = minutes
ohours = zero; if(present(hours)) ohours = hours
odays = zero; if(present(days)) odays = days
omonths = zero; if(present(months)) omonths = months
oyears = zero; if(present(years)) oyears = years

! Increment must be positive definite
if(oseconds < zero .or. ominutes < zero .or. ohours < zero .or. odays < zero .or. &
   omonths < zero .or. oyears < zero) &
   call error_handler('Illegal increment in decrement_no_leap')

!  There are a number of other bad types of decrements that should be
!  prohibited here; the subtraction is not associative
!  Easiest thing is to only let month and year be decremented by themselves
!  This is slight overkill since year is not really a problem.
if(omonths /= zero .and. (oseconds /= zero .or. ominutes /= zero .or. ohours /= zero .or. &
   odays /= zero .or. oyears /= zero)) call error_handler &
   ('decrement_no_leap: month must not be decremented with other units')
if(oyears /= zero .and. (oseconds /= zero .or. ominutes /= zero .or. ohours /= zero .or. &
   odays /= zero .or. omonths /= zero)) call error_handler &
   ('decrement_no_leap: year must not be decremented with other units')

!  For non-month and non-year can just use decrement_thirty
t = decrement_thirty(time, zero, zero, odays, ohours, ominutes, oseconds)

!  For month or year decrement, first convert to date
call get_date_no_leap(t, cyear, cmonth, cday, chour, cminute, csecond)
cmonth = cmonth - omonths
cyear = cyear - oyears

! Check for months less than 12 and fix
if(cmonth < 1) then
   cyear = cyear - 1 + (cmonth) / 12
   cmonth = cmonth - 12 * ( -1 + (cmonth) / 12)
end if

! Check for negative years
if(cyear < 1) call error_handler('Illegal date results in decrement_no_leap')

! Convert this back into a time
decrement_no_leap = set_date_no_leap(cyear, cmonth, cday, chour, cminute, csecond)

end function decrement_no_leap

! END OF decrement_date BLOCK
!=========================================================================
! START days_in_month BLOCK
! <FUNCTION NAME="days_in_month">

!   <OVERVIEW>
!       Given a time interval, gives the number of days in the
!       month corresponding to the default calendar.
!   </OVERVIEW>
!   <DESCRIPTION>
!       Given a time, computes the corresponding date given the selected
!       date time mapping algorithm.
!   </DESCRIPTION>
!   <TEMPLATE> days_in_month(time) </TEMPLATE>

!   <IN NAME="time" UNITS="" TYPE="time_type" DIM="">A time interval.</IN>
!   <OUT NAME="days_in_month" UNITS="" TYPE="integer" DIM="" DEFAULT="">
!       The number of days in the month given the selected time
!       mapping algorithm.
!   </OUT>

function days_in_month(time)

! Given a time, computes the corresponding date given the selected
! date time mapping algorithm

implicit none

integer :: days_in_month
type(time_type), intent(in) :: time

select case(calendar_type)
case(THIRTY_DAY_MONTHS)
   days_in_month = days_in_month_thirty(time)
case(GREGORIAN)
   days_in_month = days_in_month_gregorian(time)
case(JULIAN)
   days_in_month = days_in_month_julian(time)
case(NOLEAP)
   days_in_month = days_in_month_no_leap(time)
case default
   call error_handler('Invalid calendar type in days_in_month')
end select
end function days_in_month
! </FUNCTION>

!--------------------------------------------------------------------------

function days_in_month_gregorian(time)

! Returns the number of days in a gregorian month.

implicit none

integer :: days_in_month_gregorian
type(time_type), intent(in) :: time

call error_handler('days_in_month_gregorian not implemented')
days_in_month_gregorian = -1

end function days_in_month_gregorian

!--------------------------------------------------------------------------
function days_in_month_julian(time)

! Returns the number of days in a julian month.

implicit none

integer :: days_in_month_julian
type(time_type), intent(in) :: time
integer(8) :: seconds, minutes, hours, day, month, year

call get_date_julian(time, year, month, day, hours, minutes, seconds)
days_in_month_julian = days_per_month(month)
if(leap_year_julian(time) .and. month == 2) days_in_month_julian = 29

end function days_in_month_julian

!--------------------------------------------------------------------------
function days_in_month_thirty(time)

! Returns the number of days in a thirty day month (needed for transparent
! changes to calendar type).

implicit none

integer :: days_in_month_thirty
type(time_type), intent(in) :: time

days_in_month_thirty = 30

end function days_in_month_thirty

!--------------------------------------------------------------------------
function days_in_month_no_leap(time)

! Returns the number of days in a 365 day year month.

implicit none

integer :: days_in_month_no_leap
type(time_type), intent(in) :: time
integer(8) :: seconds, minutes, hours, day, month, year

call get_date_no_leap(time, year, month, day, hours, minutes, seconds)
days_in_month_no_leap= days_per_month(month)

end function days_in_month_no_leap

! END OF days_in_month BLOCK
!==========================================================================
! START OF leap_year BLOCK
! <FUNCTION NAME="leap_year">

!   <OVERVIEW>
!      Returns true if the year corresponding to the date for the
!      default calendar is a leap year. Returns false for
!      THIRTY_DAY_MONTHS and NOLEAP.
!   </OVERVIEW>
!   <DESCRIPTION>
!      Is this date in a leap year for default calendar? Returns true if the 
!      year corresponding to the date for the default calendar is a leap year. 
!      Returns false for THIRTY_DAY_MONTHS and NOLEAP.
!   </DESCRIPTION>
!   <TEMPLATE> leap_year(time) </TEMPLATE>

!   <IN NAME="time" UNITS="" TYPE="time_type" DIM="">A time interval.</IN>
!   <OUT NAME="leap_year" UNITS="" TYPE="calendar_type" DIM="" DEFAULT="">
!       True if the year corresponding to the date for the default
!       calendar is a leap year. False for THIRTY_DAY_MONTHS and
!       NOLEAP and otherwise.
!   </OUT>

function leap_year(time)

! Is this date in a leap year for default calendar?

implicit none

logical :: leap_year
type(time_type), intent(in) :: time

select case(calendar_type)
case(THIRTY_DAY_MONTHS)
   leap_year = leap_year_thirty(time)
case(GREGORIAN)
   leap_year = leap_year_gregorian(time)
case(JULIAN)
   leap_year = leap_year_julian(time)
case(NOLEAP)
   leap_year = leap_year_no_leap(time)
case default
   call error_handler('Invalid calendar type in leap_year')
end select
end function leap_year
! </FUNCTION>

!--------------------------------------------------------------------------

function leap_year_gregorian(time)

! Is this a leap year for gregorian calendar?

implicit none

logical :: leap_year_gregorian
type(time_type), intent(in) :: time

call error_handler('leap_year_gregorian not implemented')
leap_year_gregorian = .FALSE.

end function leap_year_gregorian

!--------------------------------------------------------------------------

function leap_year_julian(time)

! Returns the number of days in a julian month.

implicit none

logical :: leap_year_julian
type(time_type), intent(in) :: time
integer(8) :: seconds, minutes, hours, day, month, year

call get_date(time, year, month, day, hours, minutes, seconds)
leap_year_julian = ((year / 4 * 4) == year)

end function leap_year_julian

!--------------------------------------------------------------------------

function leap_year_thirty(time)

! No leap years in thirty day months, included for transparency. 

implicit none

logical :: leap_year_thirty
type(time_type), intent(in) :: time

leap_year_thirty = .FALSE.

end function leap_year_thirty

!--------------------------------------------------------------------------

function leap_year_no_leap(time)

! Another tough one; no leap year returns false for leap year inquiry.

implicit none

logical :: leap_year_no_leap
type(time_type), intent(in) :: time

leap_year_no_leap = .FALSE.

end function leap_year_no_leap

!END OF leap_year BLOCK
!==========================================================================
! START OF length_of_year BLOCK
! <FUNCTION NAME="length_of_year">

!   <OVERVIEW>
!      Returns the mean length of the year in the default calendar setting. 
!   </OVERVIEW>
!   <DESCRIPTION>
!      There are no arguments in this function. It returns the mean
!      length of the year in the default calendar setting.
!   </DESCRIPTION>
!   <TEMPLATE> length_of_year() </TEMPLATE>

function length_of_year()

! What is the length of the year for the default calendar type

implicit none

type(time_type) :: length_of_year

select case(calendar_type)
case(THIRTY_DAY_MONTHS)
   length_of_year = length_of_year_thirty()
case(GREGORIAN)
   length_of_year = length_of_year_gregorian()
case(JULIAN)
   length_of_year = length_of_year_julian()
case(NOLEAP)
   length_of_year = length_of_year_no_leap()
case default
   call error_handler('Invalid calendar type in length_of_year')
end select
end function length_of_year
! </FUNCTION>

!--------------------------------------------------------------------------

function length_of_year_thirty()

implicit none

type(time_type) :: length_of_year_thirty

length_of_year_thirty = set_time(INT(0,8), INT(360,8))

end function length_of_year_thirty

!---------------------------------------------------------------------------

function length_of_year_gregorian()

implicit none

type(time_type) :: length_of_year_gregorian

length_of_year_gregorian = set_time(INT(0,8), INT(0,8))

call error_handler('length_of_year_gregorian not implemented')

end function length_of_year_gregorian

!--------------------------------------------------------------------------

function length_of_year_julian()

implicit none

type(time_type) :: length_of_year_julian

length_of_year_julian = set_time(INT((24 / 4) * 60 * 60,8), INT(365,8))

end function length_of_year_julian

!--------------------------------------------------------------------------

function length_of_year_no_leap()

implicit none

type(time_type) :: length_of_year_no_leap

length_of_year_no_leap = set_time(INT(0,8), INT(365,8))

end function length_of_year_no_leap

!--------------------------------------------------------------------------

! END OF length_of_year BLOCK
!==========================================================================

! START OF days_in_year BLOCK
! <FUNCTION NAME="days_in_year">

!   <OVERVIEW>
!      Returns the number of days in the calendar year corresponding to
!      the date represented by time for the default calendar.
!   </OVERVIEW>
!   <DESCRIPTION>
!      Returns the number of days in the calendar year corresponding to
!      the date represented by time for the default calendar.
!   </DESCRIPTION>
!   <TEMPLATE> days_in_year() </TEMPLATE>
!   <IN NAME="time" TYPE="time_type">A time interval.</IN>
!   <OUT>
!      The number of days in this year for the default calendar type.
!   </OUT>


function days_in_year(time)

! What is the number of days in this year for the default calendar type

implicit none

integer :: days_in_year
type(time_type), intent(in) :: time

select case(calendar_type)
case(THIRTY_DAY_MONTHS)
   days_in_year = days_in_year_thirty(time)
case(GREGORIAN)
   days_in_year = days_in_year_gregorian(time)
case(JULIAN)
   days_in_year = days_in_year_julian(time)
case(NOLEAP)
   days_in_year = days_in_year_no_leap(time)
case default
   call error_handler('Invalid calendar type in days_in_year')
end select
end function days_in_year
! </FUNCTION>

!--------------------------------------------------------------------------

function days_in_year_thirty(time)

implicit none

integer :: days_in_year_thirty
type(time_type), intent(in) :: time

days_in_year_thirty = 360

end function days_in_year_thirty

!---------------------------------------------------------------------------

function days_in_year_gregorian(time)

implicit none

integer :: days_in_year_gregorian
type(time_type), intent(in) :: time

days_in_year_gregorian = 0

call error_handler('days_in_year_gregorian not implemented')

end function days_in_year_gregorian

!--------------------------------------------------------------------------
function days_in_year_julian(time)

implicit none

integer :: days_in_year_julian
type(time_type), intent(in) :: time

if(leap_year_julian(time)) then
   days_in_year_julian = 366
else
   days_in_year_julian = 365
endif

end function days_in_year_julian

!--------------------------------------------------------------------------

function days_in_year_no_leap(time)

implicit none

integer :: days_in_year_no_leap
type(time_type), intent(in) :: time

days_in_year_no_leap = 365

end function days_in_year_no_leap

!--------------------------------------------------------------------------

! END OF days_in_year BLOCK

!==========================================================================
! <FUNCTION NAME="month_name">

!   <OVERVIEW>
!      Returns a character string containing the name of the
!      month corresponding to month number n. 
!   </OVERVIEW>
!   <DESCRIPTION>
!      Returns a character string containing the name of the
!      month corresponding to month number n. Definition is the
!      same for all calendar types. 
!   </DESCRIPTION>
!   <TEMPLATE> month_name(n) </TEMPLATE>
!   <IN NAME="n" TYPE="integer">Month number.</IN>
!   <OUT NAME="month_name" TYPE="character">
!      The character string associated with a month. For now all
!      calendars have 12 months and will return standard names.
!   </OUT>

function month_name(n)

! Returns character string associated with a month, for now, all calendars
! have 12 months and will return standard names.

character (len=9) :: month_name
integer, intent(in) :: n
character (len = 9), dimension(12) :: months = (/'January  ', 'February ', &
          'March    ', 'April    ', 'May      ', 'June     ', 'July     ', &
          'August   ', 'September', 'October  ', 'November ', 'December '/) 

if(n < 1 .or. n > 12) call error_handler('Illegal month index')

month_name = months(n)

end function month_name
! </FUNCTION>

!==========================================================================

subroutine error_handler(s)

implicit none

character (*), intent(in) :: s

! Stub until module for error_handler available
!write(*, *) 'ERROR: In time_manager.f90: ', s
!stop

   call error_mesg ('time_manager', s, FATAL)

end subroutine error_handler

!------------------------------------------------------------------------
! <SUBROUTINE NAME="time_manager_init">

!   <OVERVIEW>
!      Write the version information to the log file.
!   </OVERVIEW>
!   <DESCRIPTION>
!      Initialization routine. This routine does not have to be called, all 
!      it does is write the version information to the log file.
!   </DESCRIPTION>
!   <TEMPLATE>time_manager_init()</TEMPLATE>

subroutine time_manager_init ( )

! initialization routine
! this routine does not have to be called, all it does is write
! the version information to the log file

integer :: unit, ierr, io

  if (module_is_initialized) return  ! silent return if already called

  unit = open_namelist_file()
  ierr=1
  do while (ierr /= 0)
    read(unit, nml=time_manager_nml, iostat=io, end=20)
    ierr = check_nml_error (io, 'time_manager_nml')
  enddo
  20 call close_file (unit)

  call write_version_number (version, tagname)
  if(mpp_pe() == mpp_root_pe()) write (stdlog(), nml=time_manager_nml)
  module_is_initialized = .true.

end subroutine time_manager_init
! </SUBROUTINE>

!------------------------------------------------------------------------
! <SUBROUTINE NAME="print_time">

!   <OVERVIEW>
!      Prints the given time_type argument as a time (using days and seconds).
!   </OVERVIEW>
!   <DESCRIPTION>
!      Prints the given time_type argument either as a time (using days and
!      seconds). NOTE: there is no check for PE number.
!   </DESCRIPTION>
!   <TEMPLATE>print_time (time,str,unit)</TEMPLATE>
!   <IN NAME="time" TYPE="time_type"> Time that will be printed. </IN>
!   <IN NAME="str" TYPE="character (len=*)" DEFAULT="TIME: or DATE:"> 
!      Character string that precedes the printed time or date.
!   </IN>
!   <IN NAME="unit" TYPE="integer">
!      Unit number for printed output. The default unit is stdout.
!   </IN>
subroutine print_time (time,str,unit)
type(time_type)  , intent(in) :: time
character (len=*), intent(in), optional :: str
integer          , intent(in), optional :: unit
integer :: ns,nd, unit_in
integer(8) :: s,d
character(len=13) :: fmt

! prints the time to standard output (or optional unit) as days and seconds
! NOTE: there is no check for PE number

  unit_in = stdout()
  if (present(unit)) unit_in = unit

  call get_time (time,s,d)

! format output
! get number of digits for days and seconds strings
   nd = int(log10(real(max(1,d))))+1
   ns = int(log10(real(max(1,s))))+1
   write (fmt,10) nd, ns
10 format ('(a,i',i2.2,',a,i',i2.2,')')

  if (present(str)) then
     write (unit_in,fmt) trim(str)//' day=', d, ', sec=', s
  else
     write (unit_in,fmt)       'TIME: day=', d, ', sec=', s
  endif

end subroutine print_time
! </SUBROUTINE>

!------------------------------------------------------------------------
! <SUBROUTINE NAME="print_date">

!   <OVERVIEW>
!      prints the time to standard output (or optional unit) as a date.
!   </OVERVIEW>
!   <DESCRIPTION>
!      Prints the given time_type argument as a date (using year,month,day,
!      hour,minutes and seconds). NOTE: there is no check for PE number.
!   </DESCRIPTION>
!   <TEMPLATE> print_date (time,str,unit)
!   </TEMPLATE>
!   <IN NAME="time" TYPE="time_type"> Time that will be printed. </IN>
!   <IN NAME="str" TYPE="character (len=*)" DEFAULT="TIME: or DATE:"> 
!      Character string that precedes the printed time or date.
!   </IN>
!   <IN NAME="unit" TYPE="integer">
!      Unit number for printed output. The default unit is stdout.
!   </IN>

subroutine print_date (time,str,unit)
type(time_type)  , intent(in) :: time
character (len=*), intent(in), optional :: str
integer          , intent(in), optional :: unit
integer(8) :: y,mo,d,h,m,s, unit_in
character(len=9) :: mon

! prints the time to standard output (or optional unit) as a date
! NOTE: there is no check for PE number

  unit_in = stdout()
  if (present(unit)) unit_in = unit

  call get_date (time,y,mo,d,h,m,s)
  mon = month_name(mo)
  if (present(str)) then
     write (unit_in,10) trim(str)//' ', y,mon(1:3),' ',d,' ',h,':',m,':',s
  else
     write (unit_in,10)       'DATE: ', y,mon(1:3),' ',d,' ',h,':',m,':',s
  endif
10 format (a,i4,1x,a3,4(a1,i2.2))

end subroutine print_date
! </SUBROUTINE>

!------------------------------------------------------------------------
! <FUNCTION NAME="valid_calendar_types">

!   <DESCRIPTION>
!     Returns a character string that describes the
!     calendar type corresponding to the input integer.
!   </DESCRIPTION>
!   <IN NAME="ncal" TYPE="integer">
!     An integer corresponding to a valid calendar type.
!   </IN>
!   <OUT NAME="valid_calendar_types" TYPE="character(len=24)">
!     A character string describing the calendar type.
!   </OUT>

function valid_calendar_types(ncal)
integer, intent(in) :: ncal
character(len=24) :: valid_calendar_types
character(len=8)  :: chtmp

if(ncal == NO_CALENDAR) then
  valid_calendar_types = 'NO_CALENDAR             '
else if(ncal == THIRTY_DAY_MONTHS) then
  valid_calendar_types = 'THIRTY_DAY_MONTHS       '
else if(ncal == JULIAN) then
  valid_calendar_types = 'JULIAN                  '
else if(ncal == GREGORIAN) then
  valid_calendar_types = 'GREGORIAN               '
else if(ncal == NOLEAP) then
  valid_calendar_types = 'NOLEAP                  '
else
  write(chtmp,'(i8)') ncal
  call error_mesg('valid_calendar_types',chtmp//' does not correspond '//&
              'to any valid calendar type.',FATAL)
endif
end function valid_calendar_types
! </FUNCTION>
!------------------------------------------------------------------------

end module time_manager_mod

! <INFO>

!   <TESTPROGRAM NAME="time_main2">  
!    <PRE>
!        use time_manager_mod
!        implicit none
!        type(time_type) :: dt, init_date, astro_base_date, time, final_date
!        type(time_type) :: next_rad_time, mid_date
!        type(time_type) :: repeat_alarm_freq, repeat_alarm_length
!        integer :: num_steps, i, days, months, years, seconds, minutes, hours
!        integer :: months2, length
!        real :: astro_days
!   
!   !Set calendar type
!   !    call set_calendar_type(THIRTY_DAY_MONTHS)
!        call set_calendar_type(JULIAN)
!   !    call set_calendar_type(NOLEAP)
!   
!   ! Set timestep
!        dt = set_time(1100, 0)
!   
!   ! Set initial date
!        init_date = set_date(1992, 1, 1)
!   
!   ! Set date for astronomy delta calculation
!        astro_base_date = set_date(1970, 1, 1, 12, 0, 0)
!   
!   ! Copy initial time to model current time
!        time = init_date
!   
!   ! Determine how many steps to do to run one year
!        final_date = increment_date(init_date, years = 1)
!        num_steps = (final_date - init_date) / dt
!        write(*, *) 'Number of steps is' , num_steps
!   
!   ! Want to compute radiation at initial step, then every two hours
!        next_rad_time = time + set_time(7200, 0)
!   
!   ! Test repeat alarm
!        repeat_alarm_freq = set_time(0, 1)
!        repeat_alarm_length = set_time(7200, 0)
!   
!   ! Loop through a year
!        do i = 1, num_steps
!   
!   ! Increment time
!        time = time + dt
!   
!   ! Test repeat alarm
!        if(repeat_alarm(time, repeat_alarm_freq, repeat_alarm_length)) &
!        write(*, *) 'REPEAT ALARM IS TRUE'
!   
!   ! Should radiation be computed? Three possible tests.
!   ! First test assumes exact interval; just ask if times are equal
!   !     if(time == next_rad_time) then
!   ! Second test computes rad on last time step that is <= radiation time
!   !     if((next_rad_time - time) < dt .and. time < next_rad) then
!   ! Third test computes rad on time step closest to radiation time
!         if(interval_alarm(time, dt, next_rad_time, set_time(7200, 0))) then
!           call get_date(time, years, months, days, hours, minutes, seconds)
!           write(*, *) days, month_name(months), years, hours, minutes, seconds
!   
!   ! Need to compute real number of days between current time and astro_base
!           call get_time(time - astro_base_date, seconds, days)
!           astro_days = days + seconds / 86400.
!   !       write(*, *) 'astro offset ', astro_days
!        end if
!   
!   ! Can compute daily, monthly, yearly, hourly, etc. diagnostics as for rad
!   
!   ! Example: do diagnostics on last time step of this month
!        call get_date(time + dt, years, months2, days, hours, minutes, seconds)
!        call get_date(time, years, months, days, hours, minutes, seconds)
!        if(months /= months2) then
!           write(*, *) 'last timestep of month'
!           write(*, *) days, months, years, hours, minutes, seconds
!        endif
!   
!   ! Example: mid-month diagnostics; inefficient to make things clear
!        length = days_in_month(time)
!        call get_date(time, years, months, days, hours, minutes, seconds)
!        mid_date = set_date(years, months, 1) + set_time(0, length) / 2
!   
!        if(time < mid_date .and. (mid_date - time) < dt) then
!           write(*, *) 'mid-month time'
!           write(*, *) days, months, years, hours, minutes, seconds
!        endif
!   
!        end do
!   
!    </PRE>
!   end program time_main2

!   </TESTPROGRAM>
!   <NOTE>
!     The Gregorian calendar type is not completely implemented, and currently
!     no effort is put on it since it doesn't differ from Julian in use between
!     1901 and 2099.
!   </NOTE>
!   <NOTE>
!     The <a name="base date">base date</a> is implicitly defined so users don't 
!     need to be concerned with it. For the curious, the base date is defined as 
!     0 seconds, 0 minutes, 0 hours, day 1, month 1, year 1 for the Julian and 
!     thirty_day_months calendars, and 1 January, 1900, 0 seconds, 0 minutes, 
!     0 hour for the Gregorian calendar.
!   </NOTE>
!   <NOTE>
!     Please note that a time is a positive definite quantity.
!   </NOTE>
!   <NOTE>
!     See the <LINK SRC="TEST PROGRAM">Test Program </LINK> for a simple program 
!     that shows some of the capabilities of the time manager.
!   </NOTE>
! </INFO>
