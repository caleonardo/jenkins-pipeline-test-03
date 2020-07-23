#!/bin/bash

# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

action=$1
branch=$2
policyrepo=$3
#cd ..  # make base_dir /home/jenkins/jenkins_agent_dir/workspace/pipeline-7-multibranch_develop/ instead of /home/jenkins/jenkins_agent_dir/workspace/pipeline-7-multibranch_develop/build
cd ../1-org/envs/
base_dir=$(pwd)
environments_regex="^(dev|nonprod|prod|shared)$"

## Terraform apply for single environment.
tf_apply() {
  local path=$1
  local tf_env=$2
  echo "*************** TERRAFORM APPLY *******************"
  echo "      At environment: ${tf_env} "
  echo "***************************************************"
  if [ -d "$path" ]; then
    cd "$path" || exit
    terraform apply -input=false -auto-approve "${tf_env}.tfplan" || exit 1
    cd "$base_dir" || exit
  else
    echo "ERROR:  ${path} does not exist"
  fi
}

## terraform init for single environment.
tf_init() {
  local path=$1
  local tf_env=$2
  echo "*************** TERRAFORM INIT *******************"
  echo "      At environment: ${tf_env} "
  echo "**************************************************"
    echo "1 - WHAT DIRECTORY ARE WE IN?"
    echo "`pwd`"
    echo "1 - -----------------------------------"

    echo "2 - SEE THE OUTPUT FOR gcloud auth list"
    gcloud auth list
    echo "2 - -----------------------------------"

    #echo "3 - CHANGE THE ACCOUT WITH gcloud config set account org-terraform@cft-seed-fe85.iam.gserviceaccount.com"
    #gcloud config set account org-terraform@cft-seed-fe85.iam.gserviceaccount.com
    #echo "3 - -----------------------------------"

    #echo "3.1 - IMPERSONATE THE TERRAFORM ACCOUNT gcloud config set auth/impersonate_service_account org-terraform@cft-seed-fe85.iam.gserviceaccount.com"
    #gcloud config set auth/impersonate_service_account org-terraform@cft-seed-fe85.iam.gserviceaccount.com
    #echo "3.1 - -----------------------------------"

    echo "4 - SEE THE NEW OUTPUT FOR gcloud auth list"
    gcloud auth list
    echo "4 - -----------------------------------"

  if [ -d "$path" ]; then
    cd "$path" || exit
    terraform init || exit 11
    cd "$base_dir" || exit
  else
    echo "ERROR:  ${path} does not exist"
  fi
}

## terraform plan for single environment.
tf_plan() {
  local path=$1
  local tf_env=$2
  echo "*************** TERRAFORM PLAN *******************"
  echo "      At environment: ${tf_env} "
  echo "**************************************************"
  if [ -d "$path" ]; then
    cd "$path" || exit
    terraform plan -input=false -out "${tf_env}.tfplan" || exit 21
    cd "$base_dir" || exit
  else
    echo "ERROR:  ${tf_env} does not exist"
  fi
}

## terraform init/plan for all valid environments matching regex.
tf_init_plan_all() {
  # shellcheck disable=SC2012
  ls "$base_dir" | while read -r component ; do
    # shellcheck disable=SC2012
    ls "$base_dir/$component" | while read -r env ; do
      if [[ "$env" =~ $environments_regex ]] ; then
       tf_dir="$base_dir/$component/$env"
       tf_init "$tf_dir" "$env"
       tf_plan "$tf_dir" "$env"
      else
        echo "$component/$env doesn't match $environments_regex; skipping"
      fi
    done
  done
}

## terraform validate for single environment.
tf_validate() {
  local path=$1
  local tf_env=$2
  local policy_file_path=$3
  echo "*************** TERRAFORM VALIDATE ******************"
  echo "      At environment: ${tf_env} "
  echo "      Using policy from: ${policy_file_path} "
  echo "*****************************************************"
  if ! command -v terraform-validator &> /dev/null; then
    echo "terraform-validator not found!  Check path or visit"
    echo "https://github.com/forseti-security/policy-library/blob/master/docs/user_guide.md#how-to-use-terraform-validator"
  else
    if [ -d "$path" ]; then
      cd "$path" || exit
      terraform show -json "${tf_env}.tfplan" > "${tf_env}.json" || exit 32
      terraform-validator validate "${tf_env}.json" --policy-path="${policy_file_path}" || exit 33
      cd "$base_dir" || exit
    else
      echo "ERROR:  ${path} does not exist"
    fi
  fi
}

# Runs single action for each instance of env in folder hierarchy.
single_action_runner() {
  # shellcheck disable=SC2012
  echo " 1 vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"
  echo "the base_dir is: $base_dir"
  echo " 1 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"

  ls "$base_dir" | while read -r component ; do
    # sort -r is added to ensure shared is first if it exists.
    # shellcheck disable=SC2012
    ls "$base_dir/$component" | sort -r | while read -r env ; do
      # perform action only if folder matches branch OR folder is shared & branch is prod.
      if [[ "$env" == "$branch" ]] || [[ "$env" == "shared" && "$branch" == "prod" ]]; then
        tf_dir="$base_dir/$component/$env"
        echo " 2 vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"
        echo echo "the tf_dir is: ${tf_dir}"
        echo " 2 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
        case "$action" in
          apply )
            tf_apply "$tf_dir" "$env"
            ;;

          init )
            tf_init "$tf_dir" "$env"
            ;;

          plan )
            tf_plan "$tf_dir" "$env"
            ;;

          validate )
            tf_validate "$tf_dir" "$env" "$policyrepo"
            ;;
          * )
            echo "unknown option: ${action}"
            ;;
        esac
      else
        echo "${env} doesn't match ${branch}; skipping"
      fi
    done
  done
}

case "$action" in
  init|plan|apply|validate )
    single_action_runner
    ;;

  planall )
    tf_init_plan_all
    ;;

  * )
    echo "unknown option: ${1}"
    exit 99
    ;;
esac
