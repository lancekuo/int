#!groovy
/* Define application name */
def APP                    = 'app'

/* Prepare eval() command for all different environment */
def DOCKER_EVAL_CI         = ''
def DOCKER_EVAL_STG        = ''
def DOCKER_EVAL_PRD        = ''

/* Pre-define tag name for docker images */
def normalized_branch_name = ''
def ci_latest_tag_name     = ''
def ci_version_tag_name    = ''
def stg_latest_tag_name    = ''
def stg_version_tag_name   = ''
def prd_latest_tag_name    = ''
def prd_version_tag_name   = ''

/* Set up the configuration file path */
def config_path            = ''
def CONFIG_CMD             = ''

def stage_name             = ""
def build_tag_ci           = ""
def COMMIT_ID              = ""
def POSSIBLE_PROD_TAG      = /(.*)-(2)-g(.*)/

def DOCKERBUILD_FILENAME   = "Dockerfile"

node {
    stage('Checkout'){
        sh 'rm -rf *'
        sh 'rm -rf .git'
        sh 'env'
        dir('src') {
            checkout scm
            /* sh 'git rev-parse --short HEAD > .git/commit-id' */
            sh "git describe --tags > .git/commit-id"
            COMMIT_ID = readFile('.git/commit-id').trim()
        }

        /* Prepare eval() command for all different environment */
        DOCKER_EVAL_CI = "${env.JF_DOCKER_CMD}".replaceAll('__HOST__', "${env.JF_DOCKER_HOST_CI}")
        DOCKER_EVAL_STG = "${env.JF_DOCKER_CMD_SWARM}".replaceAll('__HOST__', "${env.JF_DOCKER_HOST_STG}")
        DOCKER_EVAL_PRD = "${env.JF_DOCKER_CMD_SWARM}".replaceAll('__HOST__', "${env.JF_DOCKER_HOST_PRD}")

        /* Pre-define tag name for docker images */
        normalized_branch_name = "${env.BRANCH_NAME}".replaceAll('/', '-')
        ci_latest_tag_name = "${APP}:ci_build-latest"
        ci_version_tag_name = "${APP}:ci_${normalized_branch_name}-__COMMIT_ID__"
        stg_latest_tag_name = "${APP}:stg-latest"
        stg_version_tag_name = "${APP}:stg-__COMMIT_ID__"
        prd_latest_tag_name = "${APP}:prd-latest"
        prd_version_tag_name = "${APP}:prd-__COMMIT_ID__"

        /* Set up the configuration file path */
        config_path = "${env.JF_ENV_CONFIG_PATH}${APP}/__STAGE__/config.json"
        CONFIG_CMD = "aws s3 cp ${config_path} ./src"
    }

    stage('Build container'){
        stage_name = 'ci'
        sh CONFIG_CMD.replaceAll('__STAGE__', "${stage_name}")
        ci_version_tag_name = ci_version_tag_name.replaceAll('__COMMIT_ID__', "${COMMIT_ID}")
        sh "${DOCKER_EVAL_CI};docker build -f Dockerfile -t ${ci_version_tag_name} -t ${ci_latest_tag_name} ."
    }

    stage('Unit Test'){
        sh "${DOCKER_EVAL_CI};docker run --name ${APP}_${normalized_branch_name}-${env.BUILD_ID} ${ci_latest_tag_name} npm test"
        sh "${DOCKER_EVAL_CI};docker rm -f ${APP}_${normalized_branch_name}-${env.BUILD_ID}"
    }

    if("${env.BRANCH_NAME}" == "develop"){
        stage('Build STG image'){
            stg_version_tag_name = stg_version_tag_name.replaceAll('__COMMIT_ID__', "${COMMIT_ID}")
            stage_name = 'stg'
            sh CONFIG_CMD.replaceAll('__STAGE__', "${stage_name}")
            configFileProvider([configFile(fileId: '97d4fcfe-059d-4817-a332-44aaf031e6a3', targetLocation: '.', variable: 'Dockerfile-node')]) {
                def content = readFile("Dockerfile-node")
                content = content.replaceAll('__FROM__', "${ci_version_tag_name}")
                File output = new File("${env.WORKSPACE}/${DOCKERBUILD_FILENAME}")
                if (output.exists()) {
                    output.delete()
                }
                output.createNewFile()
                output.write("${content}", "UTF-8")

                sh "${DOCKER_EVAL_CI};docker build -t ${APP}:stg-${COMMIT_ID} -t ${env.JF_PREFIX_REGISTRY_CI}${stg_version_tag_name} -t ${env.JF_PREFIX_REGISTRY_CI}${stg_latest_tag_name} ."
                sh "${DOCKER_EVAL_CI};docker push ${env.JF_PREFIX_REGISTRY_CI}${stg_latest_tag_name}"
                sh "${DOCKER_EVAL_CI};docker push ${env.JF_PREFIX_REGISTRY_CI}${stg_version_tag_name}"
            }
        }

        stage('Deploy STG'){
                configFileProvider([configFile(fileId: '09523a9a-0a00-45cf-90c5-49b6fa0cf6c8', targetLocation: '.', variable: 'docker-compose-stg.yml')]) {
                    sshagent(['e94f7583-4c0e-4b7d-927c-16cc2589cee6']) {
                        pull_cmd="docker pull ${env.JF_PREFIX_REGISTRY_STG}${stg_latest_tag_name};docker pull ${env.JF_PREFIX_REGISTRY_STG}${stg_version_tag_name}"
                        sh "echo '${DOCKER_EVAL_STG};' > pull_image_stg.sh"
                        sh "echo '${pull_cmd}' >> pull_image_stg.sh"
                        sh "ssh ${env.JF_SSH_HOST_STG} 'bash -s' < pull_image_stg.sh"

                        docker_compose = readFile "docker-compose-stg.yml"
                        sh """echo 'cat << EOF > docker-compose-stg.yml
${docker_compose}
EOF' > docker-compose-stg.sh"""
                        sh "ssh ${env.JF_SSH_HOST_STG} 'bash -s' < docker-compose-stg.sh"

                        create_cmd="docker-compose -f docker-compose-stg.yml -p ${env.JF_PJ_STG} rm -f;docker-compose -f docker-compose-stg.yml -p ${env.JF_PJ_STG} up -d --force-recreate ${APP}"
                        sh "echo '${DOCKER_EVAL_STG};' > create_service_stg.sh"
                        sh "echo '${create_cmd}' >> create_service_stg.sh"
                        sh "ssh ${env.JF_SSH_HOST_STG} 'bash -s' < create_service_stg.sh"
                    }
                }
        }

        stage('Clean up - STG'){
                /* sh "${DOCKER_EVAL_CI};docker rmi ${APP}:ci-${COMMIT_ID}" */
                sh "${DOCKER_EVAL_CI};docker rmi ${env.JF_PREFIX_REGISTRY_CI}${stg_latest_tag_name} ${env.JF_PREFIX_REGISTRY_CI}${stg_version_tag_name} ${APP}:stg-${COMMIT_ID}"
        }

        if("${COMMIT_ID}" ==~ "${POSSIBLE_PROD_TAG}" ){
            stage('Build PRD image'){
                prd_version_tag_name = prd_version_tag_name.replaceAll('__COMMIT_ID__', "${COMMIT_ID}")

                stage_name = 'prd'
                sh CONFIG_CMD.replaceAll('__STAGE__', "${stage_name}")
                configFileProvider([configFile(fileId: '97d4fcfe-059d-4817-a332-44aaf031e6a3', targetLocation: '.', variable: 'Dockerfile-node')]) {
                    def content = readFile("Dockerfile-node")
                    content = content.replaceAll('__FROM__', "${ci_version_tag_name}")
                    File output = new File("${env.WORKSPACE}/${DOCKERBUILD_FILENAME}")
                    if (output.exists()) {
                        output.delete()
                    }
                    output.createNewFile()
                    output.write("${content}", "UTF-8")

                    sh "${DOCKER_EVAL_CI};docker build -t ${APP}:prd-${COMMIT_ID} -t ${env.JF_PREFIX_REGISTRY_CI}${prd_version_tag_name} -t ${env.JF_PREFIX_REGISTRY_CI}${prd_latest_tag_name} ."
                    sh "${DOCKER_EVAL_CI};docker push ${env.JF_PREFIX_REGISTRY_CI}${prd_latest_tag_name}"
                    sh "${DOCKER_EVAL_CI};docker push ${env.JF_PREFIX_REGISTRY_CI}${prd_version_tag_name}"
                }
            }

            stage('Deploy PRD'){
                    timeout(time:5, unit:'DAYS') {
                        input message:'Approve deployment?', submitter: 'lkuo'
                    }

                    configFileProvider([configFile(fileId: '4287fd2e-e0aa-45fc-adb1-7c6dc0d7cf8e', targetLocation: '.', variable: 'docker-compose-prd.yml')]) {
                        sshagent(['424caba1-b20f-4e9a-b675-16213d7593ac']) {
                            pull_cmd="docker pull ${env.JF_PREFIX_REGISTRY_PRD}${prd_latest_tag_name};docker pull ${env.JF_PREFIX_REGISTRY_PRD}${prd_version_tag_name}"
                            sh "echo '${DOCKER_EVAL_PRD};' > pull_image_prd.sh"
                            sh "echo '${pull_cmd}' >> pull_image_prd.sh"
                            sh "ssh ${env.JF_SSH_HOST_PRD} 'bash -s' < pull_image_prd.sh"

                            docker_compose = readFile "docker-compose-prd.yml"
                            sh """echo 'cat << EOF > docker-compose-prd.yml
${docker_compose}
EOF' > docker-compose-prd.sh"""
                            sh "ssh ${env.JF_SSH_HOST_PRD} 'bash -s' < docker-compose-prd.sh"

                            create_cmd="docker-compose -f docker-compose-prd.yml -p ${env.JF_PJ_PRD} rm -f;docker-compose -f docker-compose-prd.yml -p ${env.JF_PJ_PRD} up -d --force-recreate ${APP}"
                            sh "echo '${DOCKER_EVAL_PRD};' > create_service_prd.sh"
                            sh "echo '${create_cmd}' >> create_service_prd.sh"
                            sh "ssh ${env.JF_SSH_HOST_PRD} 'bash -s' < create_service_prd.sh"
                        }
                    }
            }

            stage('Clean up - PRD'){
                    sh "${DOCKER_EVAL_CI};${env.JF_PREFIX_REGISTRY_CI}${prd_latest_tag_name} ${env.JF_PREFIX_REGISTRY_CI}${prd_version_tag_name} ${APP}:prd-${COMMIT_ID}"
            }
        }
    }
}
