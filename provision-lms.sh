set -e
set -o pipefail
set -x

apps=( lms studio )
echo $DEVSTACK_WORKSPACE
# Load database dumps for the largest databases to save time
./load-db.sh edxapp
./load-db.sh edxapp_csmh
echo $DEVSTACK_WORKSPACE=/opt/atlassian/pipelines/agent/build/tmp
export BITBUCKET_CLONE_DIR=/opt/atlassian/pipelines/agent/build/tmp
# Bring edxapp containers online
for app in "${apps[@]}"; do
    echo $app
    echo $DOCKER_COMPOSE_FILES
    docker-compose $DOCKER_COMPOSE_FILES up -d $app
done
export BITBUCKET_CLONE_DIR=/opt/atlassian/pipelines/agent/build/tmp
docker-compose exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform && paver install_prereqs'

#Installing prereqs crashes the process
docker-compose restart lms

# Run edxapp migrations first since they are needed for the service users and OAuth clients
docker-compose exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform && paver update_db --settings devstack_docker'

# Create a superuser for edxapp
docker-compose exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms --settings=devstack_docker manage_user edx edx@example.com --superuser --staff'
docker-compose exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && echo "from django.contrib.auth import get_user_model; User = get_user_model(); user = User.objects.get(username=\"edx\"); user.set_password(\"edx\"); user.save()" | python /edx/app/edxapp/edx-platform/manage.py lms shell  --settings=devstack_docker'

# Create demo course and users
docker-compose exec lms bash -c '/edx/app/edx_ansible/venvs/edx_ansible/bin/ansible-playbook /edx/app/edx_ansible/edx_ansible/playbooks/demo.yml -v -c local -i "127.0.0.1," --extra-vars="COMMON_EDXAPP_SETTINGS=devstack_docker"'

# Fix missing vendor file by clearing the cache
# Create static assets for both LMS and Studio
for app in "${apps[@]}"; do
    docker-compose exec -T $app bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform && paver update_assets --settings devstack_docker'
done

