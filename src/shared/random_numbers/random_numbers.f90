module random_numbers_mod 
  ! Generic module to wrap random number generators. 
  !   The module defines a type that identifies the particular stream of random 
  !   numbers, and has procedures for initializing it and getting real numbers 
  !   in the range 0 to 1. 
  ! This version uses the Mersenne Twister to generate random numbers on [0, 1]. 
  !
  use MersenneTwister_mod, only: randomNumberSequence, & ! The random number engine.
                                 new_RandomNumberSequence, getRandomReal 
  use time_manager_mod, only: time_type, get_date
  implicit none
  private
  
  type randomNumberStream
    type(randomNumberSequence) :: theNumbers
  end type randomNumberStream
  
  interface getRandomNumbers
    module procedure getRandomNumber_Scalar, getRandomNumber_1D, getRandomNumber_2D
  end interface getRandomNumbers
  
  interface initializeRandomNumberStream
    module procedure initializeRandomNumberStream_S, initializeRandomNumberStream_V
  end interface initializeRandomNumberStream

  public :: randomNumberStream,                             &
            initializeRandomNumberStream, getRandomNumbers, &
            constructSeed
contains
  ! ---------------------------------------------------------
  ! Initialization
  ! ---------------------------------------------------------
  function initializeRandomNumberStream_S(seed) result(new) 
    integer, intent( in)     :: seed
    type(randomNumberStream) :: new
    
    new%theNumbers = new_RandomNumberSequence(seed)
    
  end function initializeRandomNumberStream_S
  ! ---------------------------------------------------------
  function initializeRandomNumberStream_V(seed) result(new) 
    integer, dimension(:), intent( in) :: seed
    type(randomNumberStream)           :: new
    
    new%theNumbers = new_RandomNumberSequence(seed)
    
  end function initializeRandomNumberStream_V
  ! ---------------------------------------------------------
  ! Procedures for drawing random numbers
  ! ---------------------------------------------------------
  subroutine getRandomNumber_Scalar(stream, number)
    type(randomNumberStream), intent(inout) :: stream
    real,                     intent(  out) :: number
    
    number = getRandomReal(stream%theNumbers)
  end subroutine getRandomNumber_Scalar
  ! ---------------------------------------------------------
  subroutine getRandomNumber_1D(stream, numbers)
    type(randomNumberStream), intent(inout) :: stream
    real, dimension(:),       intent(  out) :: numbers
    
    ! Local variables
    integer :: i
    
    do i = 1, size(numbers)
      numbers(i) = getRandomReal(stream%theNumbers)
    end do
  end subroutine getRandomNumber_1D
  ! ---------------------------------------------------------
  subroutine getRandomNumber_2D(stream, numbers)
    type(randomNumberStream), intent(inout) :: stream
    real, dimension(:, :),    intent(  out) :: numbers
    
    ! Local variables
    integer :: i
    
    do i = 1, size(numbers, 2)
      call getRandomNumber_1D(stream, numbers(:, i))
    end do
  end subroutine getRandomNumber_2D
  ! ---------------------------------------------------------
  ! Constructing a unique seed from grid cell index and model date/time
  !   Once we have the GFDL stuff we'll add the year, month, day, hour, minute
  ! ---------------------------------------------------------
  function constructSeed(i, j, time) result(seed)
    integer,         intent( in)  :: i, j
    type(time_type), intent( in) :: time
    integer, dimension(8) :: seed
    
    ! Local variables
    integer(8) :: year, month, day, hour, minute, second
    
    
    call get_date(time, year, month, day, hour, minute, second)
    seed = (/ i, j, int(year), int(month), int(day), int(hour), int(minute), int(second) /)
  end function constructSeed
end module random_numbers_mod

