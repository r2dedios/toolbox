#!/bin/bash -
# vim: ft=sh
#title           :doc_checker.sh
#description     :Script to check the Documentation of Git Repository
#author          :Alejandro Villegas Lopez (alex.ansi.c@gmail.com).
#===============================================================================




#=============================
# Global Variables
#===============================================================================
TRUE=1
FALSE=0




#=============================
# MSG Functions
#===============================================================================
# Error Message
function log_err () {
  echo -e "\033[37m[\033[31m ERR \033[37m]\033[0m $@"
}

# Warning Message
function log_warn () {
  echo -e "\033[37m[\033[33m WAR \033[37m]\033[0m $@"
}

# OK Message
function log_ok () {
  echo -e "\033[37m[\033[32m OK  \033[37m]\033[0m $@"
}

# Info Message
function log_info () {
  echo -e "\033[37m[\033[34m INF \033[37m]\033[0m $@"
}




#=============================
# AUX Functions
#===============================================================================
function check_if_file_exists () {
  [[ -f $1 ]] && { return $TRUE; } || { log_err "$1 file not found in $(pwd)"; return $FALSE; }
}




#=============================
# Git Checking Module
#===============================================================================
# Check if is a Git Repository
function check_git_is_a_git_repo () {
  [[ -d .git ]] && { log_ok "Is a Git Repository"; return $TRUE; } || { log_err "Is not a Git Repository"; return $FALSE; }
}

# Check Git
function check_git () {
  log_info "Checking Git"
  check_git_is_a_git_repo
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  log_ok "Git repo is correct"
  return $TRUE
}





#=============================
# Version File Checking Module
#===============================================================================
# Check if VERSION file exists
function check_version_file_exists () {
  check_if_file_exists "VERSION"
}

# Check VERSION format
function check_version_format () {
  egrep -q "^[0-9]+\.[0-9]+(\.[0-9]+)?(-beta)?(-LTS)?$" VERSION
  [[ $? -eq 0 ]] && { return $TRUE; } || { log_err "Version format invalid"; return $FALSE; } 
}

# Check if current version is pushed in Git
function check_version_git_tags () {
  grep -q $(cat VERSION) <<< "$(git tag)"
  [[ $? -eq 0 ]] && { return $TRUE; } || { log_warn "Current version ( $(cat VERSION) ) are not in the git remote server"; return $FALSE; } 
}

# Check VERSION file
function check_version () {
  log_info "Checking Version file"
  local rc=$TRUE

  check_version_file_exists
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  check_version_format
  [[ $? -ne $TRUE ]] && { rc=$FALSE; }

  check_version_git_tags
  [[ $? -ne $TRUE ]] && { rc=$FALSE; }

  [[ $rc == $FALSE ]] && { log_err "VERSION file check failed"; } || { log_ok "VERSION file is correct"; }
  return $TRUE
}




#=============================
# Notice File Checking Module
#===============================================================================
# Check if NOTICE file exists
function check_notice_file_exists () {
  check_if_file_exists "NOTICE.md"
}

# Check NOTICE.md file Copyright year
function check_notice_copyright_year () {
  local current_year=$(date +%Y)
  local notice_year=$(grep Copyright NOTICE.md | awk '{ print $2 }')
  [[ $current_year == $notice_year ]] && { log_ok "Copyright Year is updated"; return $TRUE; } || { log_err "Notice file Copyright Year is outdated"; return $FALSE; }

}

# Check NOTICE.md file
function check_notice () {
  log_info "Checking NOTICE.md file"
  check_notice_file_exists
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  check_notice_copyright_year
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  log_ok "NOTICE.md file is correct"
  return $TRUE
}





#=============================
# Changelog File Checking Module
#===============================================================================



# ^[0-9]+\.[0-9]+(\.[0-9]+)?(-beta)?(-LTS)? \((([0-2][0-9])|(3[0-1]))\/(([1-9])|(0[1-9])|(1[0-2]))\/([0-9]{4})\)$
function check_changelog_file_exists () {
  check_if_file_exists "CHANGELOG.md"
}

function check_changelog_if_version_is_documented () {
  local chl_versions="$(egrep '^v*[0-9]+\.[0-9]+(\.[0-9]+)?(-beta)?(-LTS)? \((([0-2][0-9])|(3[0-1]))\/(([1-9])|(0[1-9])|(1[0-2]))\/([0-9]{4})\)$' CHANGELOG.md | awk 'FS=" " { print $1 }' | sort)"
  local git_versions="$(git tag | sort)"
  local retval=$TRUE

  # Versions documented and not uploaded
  vdnu="$(comm -2 -3 <(echo "${chl_versions[@]}") <(echo "${git_versions[@]}"))"

  # Versions not documented and uploaded
  vndu="$(comm -1 -3 <(echo "${chl_versions[@]}") <(echo "${git_versions[@]}"))"

  # Check if there are versions documented but not uploaded
  for v in ${vdnu[@]}; do
    log_err "Version $v is documented in changelog but is not present on Git Repository"
    retval=$FALSE
  done

  # Check if there are versions uploaded but not documented
  for v in ${vndu[@]}; do
    log_err "Version $v is not documented in changelog but is present on Git Repository"
    retval=$FALSE
  done

  return $retval
}

function check_changelog () {
  log_info "Checking Changelog file"
  check_changelog_file_exists
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  check_changelog_if_version_is_documented
  [[ $? -ne $TRUE ]] && { log_err "CHANGELOG have erros"; return $FALSE; }

  log_ok "Changelog file is correct"
  return $TRUE
}





#=============================
# License File Checking Module
#===============================================================================
# Check if LICENSE file exists
function check_license_file_exists () {
  check_if_file_exists "LICENSE"
}

# Check if LICENSE file is Apache 2.0
function check_license_apache () {
  local license_name=$(head -1 LICENSE | sed -e 's/^[[:space:]]*//g')
  local license_version=$(sed '2q;d' LICENSE | sed -e 's/^[[:space:]]*//g' | awk '{ print $2 }' | sed 's/.$//')

  [[ "$license_name" == "Apache License" ]] && { log_ok "License is Apache Type"; return $TRUE; } || { log_err "License is not Apache"; return $FALSE; }
  [[ $license_version == "2.0" ]] && { log_ok "Apache License is at version 2.0"; return $TRUE; } || { log_err "Apache License is at version 2.0"; return $FALSE; }
}

# Check if LICENSE file is signed
function check_license_signed () {
  local fill=$(egrep "Copyright [0-9]{4} .*$" LICENSE)
  local retval_grep=$?
  local year=$(echo "$fill" | awk '{ print $2 }')

  [[ $retval_grep -eq 0 ]] && { log_ok "License signed"; } || { log_err "License is not signed"; return $FALSE; }
  [[ "$year" != $(date +%Y) ]] && { log_err "Year of the License Copyright is outdated"; return $FALSE; } || { return $TRUE; }
}

# Check LICENSE file
function check_license () {
  log_info "Checking LICENSE file"
  local rc=$TRUE

  check_license_file_exists
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  check_license_apache
  [[ $? -ne $TRUE ]] && { rc=$FALSE; }

  check_license_signed
  [[ $? -ne $TRUE ]] && { rc=$FALSE; }

  [[ $rc == $FALSE ]] && { log_err "LICENSE file check failed"; } || { log_ok "LICENSE file is correct"; }
  return $rc
}




#=============================
# Main Functions
#===============================================================================
function help_msg () {
  printf "Repo Checker Help message:
  Version: 0.1-beta

  ./autocheck.sh -p <REPO_PATH>          Check the repo in the path specified
  ./autocheck.sh -h                           Display this message
\n"
}


function get_cl_args () {
  while getopts "p:h" arg; do
    case $arg in
      p)
        CHECK_PATHS="$OPTARG"
        ;;
      h)
        help_msg
        ;;
      *)
        help_msg
        ;;
    esac
  done

}


function run () {
  cd $CHECK_PATHS
  local total_checks=5
  local retval=0

  # Check if is a Git repository
  check_git
  retval=$(($retval + $?))


  # Check version
  check_version
  retval=$(($retval + $?))


  # Check Notice
  check_notice
  retval=$(($retval + $?))


  # Check Changelog
  check_changelog
  retval=$(($retval + $?))


  # Check License
  check_license
  retval=$(($retval + $?))

  cd - &>/dev/null


  [[ $retval -eq $total_checks ]] && { log_ok "Finished without errors! :D"; } || { log_err "Docs not completed. Total errors: $(($total_checks - $retval))"; }
}

function main () {
  [[ $# -eq 0 ]] && { help_msg; return; }
  get_cl_args $@
  run
}


main $@


