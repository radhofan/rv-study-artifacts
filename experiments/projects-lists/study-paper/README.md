# Projects

### projects.txt
1859 projects that are not unknown, clone failed, test failed, and ltw failed

### flaky-tests.txt
13 projects that have failing tests on `paz` but not on `roma`
(NOT in `projects.txt`)

### no-test.txt
94 projects that have no test **when running with RV**
(in `projects.txt`, 1859 - 94 = 1765 left)

### no-coverage.txt
145 projects that have no statement AND branch coveages
(in `projects.txt`, 1765 - 145 = 1620 left)

### zero-or-one-trace.txt
20 projects only have 0 or 1 trace
(in `projects.txt`, 1620 - 20 = 1600 left)

### single-test.txt
113 projects only have 1 test
(in `projects.txt`)

### test-numbers.txt
37 projects. `mvn test` and `mvn surefire:test` run different numbers of tests
(in `projects.txt`, but we don't need to filter them out)
