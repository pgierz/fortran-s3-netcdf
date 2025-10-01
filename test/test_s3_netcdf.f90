program test_s3_netcdf
    use testdrive, only : run_testsuite, new_testsuite, testsuite_type
    use test_temp_dir, only : collect_temp_dir_tests
    use test_error_codes, only : collect_error_code_tests
    use test_helpers, only : collect_helper_tests
    implicit none
    integer :: stat
    type(testsuite_type), allocatable :: testsuites(:)

    stat = 0

    testsuites = [ &
        new_testsuite("temp_dir", collect_temp_dir_tests), &
        new_testsuite("error_codes", collect_error_code_tests), &
        new_testsuite("helpers", collect_helper_tests) &
    ]

    call run_testsuite(testsuites, error=stat)

    if (stat > 0) then
        print *, 'Test failures detected'
        stop 1
    end if

end program test_s3_netcdf
