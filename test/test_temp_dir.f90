module test_temp_dir
    use testdrive, only : new_unittest, unittest_type, error_type, check
    use s3_netcdf, only : get_optimal_temp_dir
    implicit none
    private

    public :: collect_temp_dir_tests

contains

    !> Collect all test_temp_dir tests
    subroutine collect_temp_dir_tests(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)

        testsuite = [ &
            new_unittest("optimal_temp_dir", test_optimal_temp_dir), &
            new_unittest("temp_dir_exists", test_temp_dir_exists) &
        ]

    end subroutine collect_temp_dir_tests

    !> Test that get_optimal_temp_dir returns a non-empty string
    subroutine test_optimal_temp_dir(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=:), allocatable :: temp_dir

        temp_dir = get_optimal_temp_dir()

        call check(error, len(temp_dir) > 0, "Temp dir should not be empty")
        if (allocated(error)) return

    end subroutine test_optimal_temp_dir

    !> Test that the returned temp directory exists and is writable
    subroutine test_temp_dir_exists(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=:), allocatable :: temp_dir
        logical :: dir_exists
        integer :: unit, ios

        temp_dir = get_optimal_temp_dir()

        ! Check if directory exists by trying to create a temp file
        open(newunit=unit, file=trim(temp_dir)//'/test_write.tmp', &
             status='replace', action='write', iostat=ios)

        if (ios == 0) then
            close(unit, status='delete')
            dir_exists = .true.
        else
            dir_exists = .false.
        end if

        call check(error, dir_exists, "Temp dir should exist and be writable")
        if (allocated(error)) return

    end subroutine test_temp_dir_exists

end module test_temp_dir
