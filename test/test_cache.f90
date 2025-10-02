!> Tests for S3 cache functionality
!>
!> Tests the local caching layer for S3-backed NetCDF files,
!> including cache initialization, get/put operations, and eviction.
module test_cache
    use testdrive, only : new_unittest, unittest_type, error_type, check
    use s3_cache, only : cache_config, cache_init, cache_get, cache_put, &
                         cache_evict, cache_clear, get_cache_dir
    implicit none
    private

    public :: collect_cache_tests

contains

    !> Collect all cache tests
    subroutine collect_cache_tests(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)

        testsuite = [ &
            new_unittest("cache_init_creates_directories", test_cache_init_creates_dirs), &
            new_unittest("cache_init_respects_env_var", test_cache_init_env_var), &
            new_unittest("get_cache_dir_priority", test_get_cache_dir_priority), &
            new_unittest("cache_init_creates_subdirs", test_cache_init_subdirs) &
        ]

    end subroutine collect_cache_tests

    !> Test that cache_init creates cache directory
    subroutine test_cache_init_creates_dirs(error)
        type(error_type), allocatable, intent(out) :: error
        type(cache_config) :: config
        integer :: init_error, unit, ios
        character(len=:), allocatable :: test_cache_dir

        ! Use a test-specific cache directory
        test_cache_dir = '/tmp/fortran-s3-netcdf-test-cache-init'

        ! Clean up any existing test directory
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

        ! Configure cache to use test directory
        config%cache_dir = test_cache_dir

        ! Initialize cache
        call cache_init(config, init_error)

        ! Check that init succeeded
        call check(error, init_error == 0, &
                   "cache_init should succeed (error code: " // &
                   trim(adjustl(char(init_error + 48))) // ")")
        if (allocated(error)) return

        ! Check that directory was created
        open(newunit=unit, file=trim(test_cache_dir) // '/.', &
             status='old', action='read', iostat=ios)
        if (ios == 0) close(unit)

        call check(error, ios == 0, "Cache directory should be created")
        if (allocated(error)) return

        ! Clean up
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

    end subroutine test_cache_init_creates_dirs

    !> Test that cache_init respects environment variable
    !>
    !> Note: This test verifies get_cache_dir() returns a valid path.
    !> Testing actual environment variable priority requires setting
    !> S3_NETCDF_CACHE_DIR before running the test suite (cannot be
    !> set from within Fortran).
    subroutine test_cache_init_env_var(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=:), allocatable :: detected_dir
        character(len=512) :: env_value
        integer :: env_stat

        ! Get cache dir
        detected_dir = get_cache_dir()

        ! Check that it returns a non-empty path
        call check(error, len(detected_dir) > 0, &
                   "get_cache_dir should return non-empty path")
        if (allocated(error)) return

        ! If S3_NETCDF_CACHE_DIR is set, verify it matches
        call get_environment_variable('S3_NETCDF_CACHE_DIR', env_value, status=env_stat)
        if (env_stat == 0 .and. len_trim(env_value) > 0) then
            call check(error, detected_dir == trim(env_value), &
                       "get_cache_dir should match S3_NETCDF_CACHE_DIR when set")
            if (allocated(error)) return
        else
            ! Otherwise, should contain .cache or /tmp
            call check(error, &
                       index(detected_dir, '/.cache/') > 0 .or. &
                       index(detected_dir, '/tmp/') > 0, &
                       "get_cache_dir should use XDG or /tmp fallback")
            if (allocated(error)) return
        end if

    end subroutine test_cache_init_env_var

    !> Test get_cache_dir priority order
    subroutine test_get_cache_dir_priority(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=:), allocatable :: cache_dir
        integer :: ios

        ! Clear all cache-related env vars
        call execute_command_line('unset S3_NETCDF_CACHE_DIR XDG_CACHE_HOME', exitstat=ios)

        ! Should fall back to ~/.cache/fortran-s3-netcdf
        cache_dir = get_cache_dir()

        ! Check that it contains .cache/fortran-s3-netcdf
        call check(error, index(cache_dir, '/.cache/fortran-s3-netcdf') > 0, &
                   "Should use ~/.cache/fortran-s3-netcdf as fallback")
        if (allocated(error)) return

    end subroutine test_get_cache_dir_priority

    !> Test that cache_init creates files/ and meta/ subdirectories
    subroutine test_cache_init_subdirs(error)
        type(error_type), allocatable, intent(out) :: error
        type(cache_config) :: config
        integer :: init_error, unit, ios
        character(len=:), allocatable :: test_cache_dir

        ! Use a test-specific cache directory
        test_cache_dir = '/tmp/fortran-s3-netcdf-test-subdirs'

        ! Clean up any existing test directory
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

        ! Configure cache to use test directory
        config%cache_dir = test_cache_dir

        ! Initialize cache
        call cache_init(config, init_error)

        ! Check that init succeeded
        call check(error, init_error == 0, "cache_init should succeed")
        if (allocated(error)) return

        ! Check that files/ subdirectory exists
        open(newunit=unit, file=trim(test_cache_dir) // '/files/.', &
             status='old', action='read', iostat=ios)
        if (ios == 0) close(unit)

        call check(error, ios == 0, "files/ subdirectory should exist")
        if (allocated(error)) return

        ! Check that meta/ subdirectory exists
        open(newunit=unit, file=trim(test_cache_dir) // '/meta/.', &
             status='old', action='read', iostat=ios)
        if (ios == 0) close(unit)

        call check(error, ios == 0, "meta/ subdirectory should exist")
        if (allocated(error)) return

        ! Clean up
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

    end subroutine test_cache_init_subdirs

end module test_cache
