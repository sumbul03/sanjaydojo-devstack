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


# Create static assets for both LMS and Studio
for app in "${apps[@]}"; do
    docker-compose exec -T $app bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform && paver update_assets --settings devstack_docker'
done

