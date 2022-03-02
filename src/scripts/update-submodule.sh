function pull-push() {
  git pull --no-edit
  git push -u origin ${CIRCLE_BRANCH}
}

function check() {
  if [ $? -ne 0 ]; then
    for i in {2..10};
    do
      echo -e "\n<< Retry $i >>\n"
      sleep 1
      pull-push
      if [ $? -eq 0 ]; then
        break
      fi
    done
    if [ $i -eq 10 ]; then
      echo -e "\n tried 10 times, but it failed, so it ends. \n"
      exit 1
    fi
  else
    echo 'Success'
  fi
}

if [ -n ${MODULE_NAME} ]; then
  module_name=$(eval echo ${MODULE_NAME})
  commit_message=$(eval echo ${COMMIT_MESSAGE})
  if [ "${commit_message}" = "[skip ci] update submodule" ]; then
    commit_message="${commit_message}: ${module_name}"
  fi
  reponame=$(echo $CIRCLE_REPOSITORY_URL | awk -F "/" '{ print $NF }' | awk -F "." '{ print $(NF-1) }')
  submodule_url=$(echo ${CIRCLE_REPOSITORY_URL} | sed "s/${reponame}/${module_name}/")
  _key=$(eval echo ${SUBM_FINGER_PRINT} | sed -e 's/://g')
  export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_${_key}"
  git config --global user.email "submodule.updater@rhems-japan.co.jp"
  git config --global user.name "submodule-updater"

  if [ -e ".gitmodules" ]; then
    echo -e "already exists .gitmodule\n"
    paths=$(echo $(grep "path=*" .gitmodules | awk '{print $3}'))
    if [[ $paths =~ $module_name ]]; then
      N=$(grep -n "path = $module_name" .gitmodules | sed -e 's/:.*//g')
      branch_name=$(awk "NR==$N+2" .gitmodules | awk '{print $3}')
      echo $branch_name
    else
      echo -e "no setting in .gitmodule\n"
      git submodule add --quiet --force -b ${CIRCLE_BRANCH} ${submodule_url}
    fi
  else
    echo -e "no exists .gitmodule\n"
    git submodule add --quiet --force -b ${CIRCLE_BRANCH} ${submodule_url}
  fi

  git checkout ${CIRCLE_BRANCH}
  git submodule sync
  git submodule update --init --remote --recursive ${module_name}
  git status

  _key=$(eval echo ${MASTER_FINGER_PRINT} | sed -e 's/://g')
  export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_${_key}"
  git branch --set-upstream-to=origin/${CIRCLE_BRANCH} ${CIRCLE_BRANCH}
  git pull --no-edit
  sleep 3 # after delete
  git commit -a -m "${commit_message}" || true
  set +e
  git push -u origin ${CIRCLE_BRANCH}
  RESULT=$?
  echo "RESULT = ${RESULT}"
  if [ $RESULT -ne 0 ]; then
    for i in {2..10};
    do
      echo -e "\n<< Retry $i >>\n"
      sleep 1
      git pull --no-edit
      git push -u origin ${CIRCLE_BRANCH}
      if [ $? -eq 0 ]; then
        break
      fi
    done
    if [ $i -eq 10 ]; then
      echo -e "\n tried 10 times, but it failed, so it ends. \n"
      exit 1
    fi
  else
    echo 'Success'
  fi

else
  echo "target not found."
fi
