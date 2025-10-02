!> Local caching layer for S3-backed NetCDF files
!>
!> Provides XDG-compliant disk caching with ETag validation to avoid
!> redundant S3 downloads for repeated file access.
!>
!> Cache Architecture:
!>   - Location: $S3_NETCDF_CACHE_DIR or $XDG_CACHE_HOME/fortran-s3-netcdf
!>               or ~/.cache/fortran-s3-netcdf
!>   - Structure: files/ (cached NetCDF) and meta/ (metadata) subdirs
!>   - Naming: SHA256 hash of S3 URI (first 16 hex characters)
!>   - Metadata: Plain text with uri, size, cached_at, etag, etc.
!>
!> Public API:
!>   - cache_init: Initialize cache directory structure
!>   - cache_get: Check if URI is cached and valid, return local path
!>   - cache_put: Store downloaded file in cache with metadata
!>   - cache_evict: Remove old/large files based on policy
!>   - cache_clear: Remove all cached files
!>
!> Author: Paul Gierz <paul.gierz@awi.de>
!> License: MIT
module s3_cache
    use iso_fortran_env, only: int64
    implicit none
    private

    ! Public API
    public :: cache_config
    public :: cache_init
    public :: cache_get
    public :: cache_put
    public :: cache_evict
    public :: cache_clear
    public :: get_cache_dir

    !> Cache configuration type
    type :: cache_config
        logical :: enabled = .true.
        character(len=:), allocatable :: cache_dir
        integer(int64) :: max_size_bytes = 10737418240_int64  ! 10 GB default
        integer :: ttl_seconds = 604800  ! 7 days default
        logical :: validate_etag = .true.
    end type cache_config

    ! Module-level cache configuration (singleton pattern)
    type(cache_config), save :: default_config

contains

    !> Initialize cache directory structure
    !>
    !> Creates the cache root directory and subdirectories (files/, meta/)
    !> if they don't exist. Determines cache location from environment
    !> variables in priority order:
    !>   1. S3_NETCDF_CACHE_DIR
    !>   2. XDG_CACHE_HOME/fortran-s3-netcdf
    !>   3. ~/.cache/fortran-s3-netcdf (fallback)
    !>
    !> @param config Cache configuration (optional, uses default if not provided)
    !> @param error Error code: 0=success, non-zero=failure
    subroutine cache_init(config, error)
        type(cache_config), intent(in), optional :: config
        integer, intent(out) :: error
        character(len=:), allocatable :: cache_root
        integer :: exit_status

        error = 0

        ! Determine cache directory
        if (present(config)) then
            if (allocated(config%cache_dir)) then
                cache_root = config%cache_dir
            else
                cache_root = get_cache_dir()
            end if
        else
            cache_root = get_cache_dir()
        end if

        ! Create main cache directory
        call execute_command_line('mkdir -p ' // cache_root, exitstat=exit_status)
        if (exit_status /= 0) then
            error = 1
            return
        end if

        ! Create files/ subdirectory
        call execute_command_line('mkdir -p ' // cache_root // '/files', exitstat=exit_status)
        if (exit_status /= 0) then
            error = 2
            return
        end if

        ! Create meta/ subdirectory
        call execute_command_line('mkdir -p ' // cache_root // '/meta', exitstat=exit_status)
        if (exit_status /= 0) then
            error = 3
            return
        end if

    end subroutine cache_init

    !> Check if S3 URI is cached and return local file path
    !>
    !> Computes cache key from URI, checks if cached file exists,
    !> optionally validates ETag if configured, and returns path
    !> to local cached file if valid.
    !>
    !> @param uri S3 URI (e.g., s3://bucket/path/file.nc)
    !> @param local_path Output: path to cached file if cache hit
    !> @param is_cached Output: .true. if cache hit, .false. if miss
    !> @param config Cache configuration (optional)
    !> @param error Error code: 0=success, non-zero=failure
    subroutine cache_get(uri, local_path, is_cached, config, error)
        character(len=*), intent(in) :: uri
        character(len=:), allocatable, intent(out) :: local_path
        logical, intent(out) :: is_cached
        type(cache_config), intent(in), optional :: config
        integer, intent(out) :: error

        is_cached = .false.
        error = -1
        ! TODO: Implementation
    end subroutine cache_get

    !> Store downloaded file in cache with metadata
    !>
    !> Copies file to cache directory with hash-based name,
    !> writes metadata file with URI, size, ETag, timestamps, etc.
    !>
    !> @param uri S3 URI that was downloaded
    !> @param local_file Path to local file to cache
    !> @param etag ETag from S3 HEAD/GET response (optional)
    !> @param config Cache configuration (optional)
    !> @param error Error code: 0=success, non-zero=failure
    subroutine cache_put(uri, local_file, etag, config, error)
        character(len=*), intent(in) :: uri
        character(len=*), intent(in) :: local_file
        character(len=*), intent(in), optional :: etag
        type(cache_config), intent(in), optional :: config
        integer, intent(out) :: error

        error = -1
        ! TODO: Implementation
    end subroutine cache_put

    !> Evict old or large cached files based on policy
    !>
    !> Removes cached files that exceed TTL or when total cache
    !> size exceeds max_size_bytes. Uses LRU policy (least recently
    !> accessed files removed first).
    !>
    !> @param config Cache configuration (optional)
    !> @param error Error code: 0=success, non-zero=failure
    subroutine cache_evict(config, error)
        type(cache_config), intent(in), optional :: config
        integer, intent(out) :: error

        error = -1
        ! TODO: Implementation
    end subroutine cache_evict

    !> Clear all cached files and metadata
    !>
    !> Removes all files from cache directories. Useful for testing
    !> or manual cache reset.
    !>
    !> @param config Cache configuration (optional)
    !> @param error Error code: 0=success, non-zero=failure
    subroutine cache_clear(config, error)
        type(cache_config), intent(in), optional :: config
        integer, intent(out) :: error

        error = -1
        ! TODO: Implementation
    end subroutine cache_clear

    !> Get cache directory path from environment
    !>
    !> Determines cache location in priority order:
    !>   1. S3_NETCDF_CACHE_DIR environment variable
    !>   2. XDG_CACHE_HOME/fortran-s3-netcdf
    !>   3. ~/.cache/fortran-s3-netcdf (fallback)
    !>
    !> @return Allocatable string with cache directory path
    function get_cache_dir() result(cache_dir)
        character(len=:), allocatable :: cache_dir
        character(len=512) :: env_value
        integer :: env_stat

        ! Priority 1: S3_NETCDF_CACHE_DIR
        call get_environment_variable('S3_NETCDF_CACHE_DIR', env_value, status=env_stat)
        if (env_stat == 0 .and. len_trim(env_value) > 0) then
            cache_dir = trim(env_value)
            return
        end if

        ! Priority 2: XDG_CACHE_HOME/fortran-s3-netcdf
        call get_environment_variable('XDG_CACHE_HOME', env_value, status=env_stat)
        if (env_stat == 0 .and. len_trim(env_value) > 0) then
            cache_dir = trim(env_value) // '/fortran-s3-netcdf'
            return
        end if

        ! Priority 3: ~/.cache/fortran-s3-netcdf (fallback)
        call get_environment_variable('HOME', env_value, status=env_stat)
        if (env_stat == 0 .and. len_trim(env_value) > 0) then
            cache_dir = trim(env_value) // '/.cache/fortran-s3-netcdf'
            return
        end if

        ! Absolute fallback (should rarely happen)
        cache_dir = '/tmp/fortran-s3-netcdf-cache'
    end function get_cache_dir

end module s3_cache
