#!/usr/bin/env bash

# Boilerplate (see https://solvedata.atlassian.net/wiki/x/rwB1Cg)

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
IFS=$'\n\t'

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# End of boilerplate

readonly TEST_REPORT_DIR="./_build/test/test_reports"
readonly TEST_REPORT_FILE="${TEST_REPORT_DIR}/exunit_summarizer-tests.json"
readonly TEST_REPORT_OUTPUT="./_build/test_report_output.txt"
readonly SAMPLE_SUCCESS_TEST_REPORT_FILE="./test/files/success-exunit_summarizer-tests.json"
readonly SAMPLE_SUCCESS_TEST_REPORT_OUTPUT="./test/files/success-test_report_output.txt"
readonly SAMPLE_FAILURE_TEST_REPORT_FILE="./test/files/failure-exunit_summarizer-tests.json"
readonly SAMPLE_FAILURE_TEST_REPORT_OUTPUT="./test/files/failure-test_report_output.txt"

normalise_report_json() {
  local -r report_file="$1"
  # Round to whole seconds & remove the root directory from the fully qualified path
  jq --arg root_dir "${DIR}" -c '. + {time: (.time | round), file: (.file | sub($root_dir; "<ROOT>"))}' "${report_file}"
}

assert_report_json_mostly_equal() {
  local -r test_file="$1"
  local -r sample_file="$2"

  local -r normalised_test_file="${test_file}.normalised"
  # Apply the normalisation before checking for equality
  normalise_report_json "${test_file}" > "${normalised_test_file}"

  if diff --text "${normalised_test_file}" "${sample_file}"; then
    echo "[PASS] Report JSON files are (effectively) identical: ${normalised_test_file} == ${sample_file}"
  else
    echo "[FAIL] Report JSON files differ(in a way that matters). See output above: ${normalised_test_file} == ${sample_file}"
    return 4
  fi
}

assert_file_equal() {
  local -r test_file="$1"
  local -r sample_file="$2"

  if diff --text "${test_file}" "${sample_file}"; then
    echo "[PASS] Files are identical: ${test_file} == ${sample_file}"
  else
    echo "[FAIL] Files differ. See output above: ${test_file} == ${sample_file}"
    return 4
  fi
}

assert_exists() {
  local -r file="$1"
  if [[ -f "${file}" ]]; then
    echo "[PASS] File exists(as expected): ${file}"
  else
    echo "[FAIL] File doesn't exist: ${file}"
    return 5
  fi
}

assert_not_exists () {
  local -r file="$1"
  if [[ -f "${file}" ]]; then
    echo "[FAIL] File exists: ${file}"
    return 6
  else
    echo "[PASS] File doesn't exist(as expected): ${file}"
  fi
}

cmd_should_pass() {
  set +e
  "$@"; local -r return_code="$?" || return 10
  set -e

  if [[ ${return_code} == 0 ]]; then
    echo "[PASS] Command returned ${return_code} == 0:" "$@"
  else
    echo "[FAIL] Command returned ${return_code}, was expecting success:" "$@"
    return 7
  fi
}

cmd_should_fail() {
  set +e
  "$@"; local -r return_code="$?" || return 10
  set -e
  if [[ ${return_code} == 0 ]]; then
    echo "[FAIL] Command returned ${return_code}, was expecting failure:" "$@"
    return 8
  else
    echo "[PASS] Command returned ${return_code}:" "$@"
  fi
}

clean() {
  rm -rf "${TEST_REPORT_DIR}"
  rm -rf "${TEST_REPORT_OUTPUT}"
}

run_code_tests() {
  mix compile

  echo "Cleaning up old reports to ensure a clean slate."
  rm -rf "${TEST_REPORT_DIR}"
  echo "Run the app's tests. Failures here are legitimate failures."
  mix test
  assert_exists "${TEST_REPORT_FILE}"
  echo "[PASS] Normal tests all pass. Moving on to testing reporting systems."
}

run_success_report_test() {
  clean

  assert_not_exists "${TEST_REPORT_FILE}"

  export MAKE_TESTS_FAIL=""
  export MAKE_TESTS_SLOW="slow tests please"
  echo "Running tests in 'pass' mode"
  cmd_should_pass mix test --seed 0 test/exunit_summarizer_test.exs

  assert_exists "${TEST_REPORT_FILE}"
  assert_report_json_mostly_equal "${TEST_REPORT_FILE}" "${SAMPLE_SUCCESS_TEST_REPORT_FILE}"

  cmd_should_pass mix test.report
  mix test.report >"${TEST_REPORT_OUTPUT}" 2>&1

  assert_file_equal "${TEST_REPORT_OUTPUT}" "${SAMPLE_SUCCESS_TEST_REPORT_OUTPUT}"

  mix test.report.clean

  assert_not_exists "${TEST_REPORT_FILE}"
}

run_failure_report_test() {
  clean

  assert_not_exists "${TEST_REPORT_FILE}"

  export MAKE_TESTS_FAIL="this test intentionally fails"
  export MAKE_TESTS_SLOW="slow tests please"
  echo "Checking that the report generates correctly when tests fail"
  echo " (expect Elixir test failures)"
  cmd_should_fail mix test --seed 0 test/exunit_summarizer_test.exs

  assert_exists "${TEST_REPORT_FILE}"
  assert_report_json_mostly_equal "${TEST_REPORT_FILE}" "${SAMPLE_FAILURE_TEST_REPORT_FILE}"

  export MIX_ENV="test"
  cmd_should_fail mix test.report
  (mix test.report || true) >"${TEST_REPORT_OUTPUT}" 2>&1

  assert_file_equal "${TEST_REPORT_OUTPUT}" "${SAMPLE_FAILURE_TEST_REPORT_OUTPUT}"

  mix test.report.clean
  unset MIX_ENV

  assert_not_exists "${TEST_REPORT_FILE}"
}

run_report_clean_test() {
  clean

  echo "Testing that test.report.clean works when the report folder is not present."
  assert_not_exists "${TEST_REPORT_FILE}"
  cmd_should_pass mix test.report.clean

  echo "Testing that test.report.clean only cleans up test report files."

  mkdir "${TEST_REPORT_DIR}"
  touch "${TEST_REPORT_DIR}/example.txt"
  touch "${TEST_REPORT_DIR}/example.json"
  touch "${TEST_REPORT_DIR}/my-deleted-app-tests.json"
  touch "${TEST_REPORT_DIR}/my-deleted-app-tests.json.bak"
  cmd_should_pass mix test.report.clean

  assert_exists "${TEST_REPORT_DIR}/example.txt"
  assert_exists "${TEST_REPORT_DIR}/example.json"
  assert_not_exists  "${TEST_REPORT_DIR}/my-deleted-app-tests.json"
  assert_exists "${TEST_REPORT_DIR}/my-deleted-app-tests.json.bak"
}

main () {
  export MIX_TEST_REPORT_COLOR=1
  run_code_tests

  run_success_report_test

  run_failure_report_test

  run_report_clean_test

  echo "[PASS] All tests pass."
}

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
  main "$@"
fi
