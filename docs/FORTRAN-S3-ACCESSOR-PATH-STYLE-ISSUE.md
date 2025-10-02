# Issue: fortran-s3-accessor Only Supports Virtual-Host Style URLs

**Date**: 2025-10-02
**Affects**: fortran-s3-accessor v1.1.0
**Impact**: Cannot use with MinIO on localhost or many S3-compatible services
**Priority**: High - blocks authenticated testing in fortran-s3-netcdf

## Problem Summary

fortran-s3-accessor currently only supports **virtual-host style** S3 URLs, which are incompatible with:
- MinIO running on localhost (no DNS for `bucket.localhost`)
- Many S3-compatible services (Ceph, Wasabi, etc.)
- Local testing scenarios requiring authentication

This blocks fortran-s3-netcdf from testing cache integration with authenticated MinIO downloads.

## Current Behavior

### URL Construction (s3_http.f90, lines 233-240)

```fortran
! Build URL
if (current_config%use_https) then
    write(url, '(A,A,A,A,A,A)') 'https://', &
        trim(current_config%bucket), '.', &
        trim(current_config%endpoint), '/', &
        trim(key)
else
    write(url, '(A,A,A,A,A,A)') 'http://', &
        trim(current_config%bucket), '.', &
        trim(current_config%endpoint), '/', &
        trim(key)
end if
```

**Result**: Always constructs virtual-host style URLs:
```
https://bucket-name.s3.amazonaws.com/path/to/object
```

### Why This Fails on Localhost

When using MinIO on `localhost:9000` with bucket `test-bucket`:
```fortran
config%endpoint = "localhost:9000"
config%bucket = "test-bucket"
```

Produces:
```
http://test-bucket.localhost:9000/ocean_surface_small.nc
```

**Problem**: `test-bucket.localhost` is not a valid DNS name and cannot resolve.

## Required Solution: Add Path-Style URL Support

### What Path-Style URLs Look Like

Instead of:
```
http://bucket.endpoint/key          (virtual-host style)
```

Use:
```
http://endpoint/bucket/key          (path style)
```

### Example Comparison

| Style | URL |
|-------|-----|
| Virtual-host (current) | `https://my-bucket.s3.amazonaws.com/data/file.nc` |
| Path-style (needed) | `https://s3.amazonaws.com/my-bucket/data/file.nc` |

Both work with AWS S3. Path-style is required for:
- MinIO on localhost
- Many S3-compatible services
- Development/testing scenarios

## Proposed Implementation

### 1. Add Configuration Flag

In `s3_config` type (s3_http.f90, around line 57):

```fortran
type, public :: s3_config
    character(len=256) :: bucket = ''
    character(len=256) :: region = 'us-east-1'
    character(len=256) :: endpoint = 's3.amazonaws.com'
    character(len=256) :: access_key = ''
    character(len=256) :: secret_key = ''
    logical :: use_https = .true.
    logical :: use_path_style = .false.   ! NEW: default to virtual-host for AWS compatibility
end type s3_config
```

### 2. Update URL Construction

Replace the URL building code in `s3_get_object()` (and similar locations in `s3_put_object()`, `s3_delete_object()`, `s3_object_exists()`):

```fortran
! Build URL - support both virtual-host and path-style
if (current_config%use_path_style) then
    ! Path-style: http://endpoint/bucket/key
    if (current_config%use_https) then
        write(url, '(A,A,A,A,A,A)') 'https://', &
            trim(current_config%endpoint), '/', &
            trim(current_config%bucket), '/', &
            trim(key)
    else
        write(url, '(A,A,A,A,A,A)') 'http://', &
            trim(current_config%endpoint), '/', &
            trim(current_config%bucket), '/', &
            trim(key)
    end if
else
    ! Virtual-host style: http://bucket.endpoint/key (original behavior)
    if (current_config%use_https) then
        write(url, '(A,A,A,A,A,A)') 'https://', &
            trim(current_config%bucket), '.', &
            trim(current_config%endpoint), '/', &
            trim(key)
    else
        write(url, '(A,A,A,A,A,A)') 'http://', &
            trim(current_config%bucket), '.', &
            trim(current_config%endpoint), '/', &
            trim(key)
    end if
end if
```

### 3. Update Fallback Function

Apply same changes to `s3_get_object_fallback()` (around line 307).

### 4. Update URI Parsing Functions

The `parse_s3_uri()` function (s3_http.f90, line 84+) also needs attention. When using path-style URLs, the bucket from the URI still needs to be extracted from `s3://bucket/key` format, but the config's bucket field should be overridden for that specific request.

For `s3_get_uri()` and related URI functions, the bucket comes from the URI, not from config. These should work correctly with path-style as long as the URL building uses the extracted bucket properly.

## Locations to Update in s3_http.f90

1. **Type definition** (~line 57): Add `use_path_style` field
2. **s3_get_object()** (~line 233): Update URL building
3. **s3_get_object_fallback()** (~line 307): Update URL building
4. **s3_put_object()** (~line 400+): Update URL building
5. **s3_delete_object()** (~line 530+): Update URL building
6. **s3_object_exists()**: Update URL building if it exists

## Testing Requirements

### Unit Tests to Add (test/test_s3_http.f90)

```fortran
subroutine test_path_style_url_construction(error)
    type(error_type), allocatable, intent(out) :: error
    type(s3_config) :: config

    ! Test path-style URL construction
    config%endpoint = "localhost:9000"
    config%bucket = "test-bucket"
    config%use_https = .false.
    config%use_path_style = .true.
    call s3_init(config)

    ! When getting object, URL should be path-style
    ! Expected: http://localhost:9000/test-bucket/data/file.nc
    ! Not: http://test-bucket.localhost:9000/data/file.nc

    ! (Add actual test implementation using mock curl)
end subroutine

subroutine test_virtual_host_default(error)
    type(error_type), allocatable, intent(out) :: error

    ! Ensure default behavior (virtual-host) is unchanged
    ! for backwards compatibility
end subroutine
```

### Integration Test

The MinIO integration test in fortran-s3-netcdf will validate this works:

```fortran
! In test_minio_integration.f90
config%endpoint = "localhost:9000"
config%use_https = .false.
config%use_path_style = .true.  ! Enable for MinIO
config%access_key = "minioadmin"
config%secret_key = "minioadmin123"
call s3_init(config)
```

## Benefits

1. **MinIO Support**: Can test with local MinIO instances
2. **S3-Compatible Services**: Works with Ceph, Wasabi, DigitalOcean Spaces, etc.
3. **Backward Compatible**: Default behavior unchanged (virtual-host)
4. **Standards Compliant**: Both URL styles are valid S3 API patterns

## References

- AWS S3 Documentation: [Virtual hosting vs. path-style requests](https://docs.aws.amazon.com/AmazonS3/latest/userguide/VirtualHosting.html)
- MinIO Documentation: Path-style is required for localhost without DNS configuration
- fortran-s3-accessor CLAUDE.md: Notes that URL encoding is unsupported, but path-style is orthogonal to that issue

## Related Issues

- fortran-s3-netcdf: Cannot test cache with authenticated MinIO downloads
- Authentication support (AWS Signature v4) is a separate issue planned for v1.2.0
- However, once auth is implemented, path-style will be required for non-AWS endpoints

## Workaround for Current fortran-s3-netcdf Testing

Until this is fixed, fortran-s3-netcdf can test with public/anonymous MinIO buckets:
```bash
mc anonymous set download local/test-bucket
```

This allows testing without authentication, but doesn't validate the full production workflow.
