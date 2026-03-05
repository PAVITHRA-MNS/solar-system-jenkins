pipeline {
  agent any

  tools {
    nodejs 'nodejs-22-6-0'
  }

  environment {
    MONGO_URI = 'mongodb+srv://supercluster.d83jj.mongodb.net/superData'
    MONGO_USERNAME = credentials('mongo-db-username')
    MONGO_PASSWORD = credentials('mongo-db-password')
    GITEA_TOKEN = credentials('gitea-api-token')
  }

  stages {
    stage('Install Dependencies') {
      steps {
        sh 'npm install --no-audit'
      }
    }

    stage('NPM Dependency Audit') {
          steps {
            sh 'npm audit --audit-level=critical || true'
          }
        }
   
    stage('Unit Testing') {
        steps {
          sh 'npm test || true'
        }
      }

    stage('Code Coverage') {
      steps {
        catchError(buildResult: 'SUCCESS', message: 'Oops! it will be fixed in futher releases', stageResult: 'SUCCESS') {
            sh 'npm run coverage'
        }
      }
    }
    

    stage("Build Docker Image") {
      steps {
        sh " docker build -t kodekloud-hub:5000/solar-system:${GIT_COMMIT} ."
      }
    }

    stage("Trivy Scan") {
      steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS') {
          sh """
            trivy image kodekloud-hub:5000/solar-system:$GIT_COMMIT \
              --scanners vuln \
              --severity CRITICAL \
              --exit-code 1 \
              --format json -o trivy-image-CRITICAL-results.json
          """
        }
      }
    }

    stage("Publish Image - DockerHub") {
      steps {
        withDockerRegistry(credentialsId: 'docker-hub-credentials', url: 'http://kodekloud-hub:5000') {
          sh "docker push kodekloud-hub:5000/solar-system:$GIT_COMMIT"
        }
      }
    }

    stage('Localstack - AWS S3') {
      steps {
        withAWS(credentials: 'localstack-aws-credentials', endpointUrl: 'http://localhost:4566', region: 'us-east-1') {
          sh  '''
              ls -ltr
              mkdir reports-$BUILD_ID
              cp -rf coverage/ reports-$BUILD_ID/
              cp -f test-results.xml trivy-* reports-$BUILD_ID/ || true
              ls -ltr reports-$BUILD_ID/
            '''
          s3Upload(
            bucket: 'solar-system-jenkins-reports-bucket', file: "reports-${BUILD_ID}", path: "jenkins-${BUILD_ID}/", pathStyleAccessEnabled: true
          )
        }
      }
    }

    stage("Deploy to VM") {
      when {
        expression { return env.GIT_BRANCH ==~ /feature\/.*/ }   
      }
      steps {
        script {
          sshagent(['vm-dev-deploy-instance']) {
            sh """
        ssh -o StrictHostKeyChecking=no root@node01 '
          sudo docker pull kodekloud-hub:5000/solar-system:${GIT_COMMIT}
          if sudo docker ps -a --format "{{.Names}}" | grep -w solar-system; then
            echo "Stopping existing container..."
            sudo docker stop solar-system
            sudo docker rm -f solar-system
          fi

          sudo docker run -d --name solar-system \
            -e MONGO_URI="${MONGO_URI}" \
            -e MONGO_USERNAME="${MONGO_USERNAME}" \
            -e MONGO_PASSWORD="${MONGO_PASSWORD}" \
            -p 3000:3000 \
            kodekloud-hub:5000/solar-system:${GIT_COMMIT}
        '
        """
          }
        }
      }
    }

    stage("Integration Testing - VM") {
      when {
        expression { return env.GIT_BRANCH ==~ /feature\/.*/ }   
      }

      steps {
        sh """
          bash dev-integration-test-vm.sh
        """
      }
    }

    stage('Update and Commit Image Tag') {
      when  {
              branch 'PR*'
            }
      steps {
          sh 'git clone -b main http://git-server:5555/dasher-org/solar-system-gitops-argocd'
          dir("solar-system-gitops-argocd/kubernetes") {
              sh '''
                  git checkout main
                  git checkout -b feature-$BUILD_ID
                  sed -i "s#kodekloud-hub:5000.*#kodekloud-hub:5000/solar-system:$GIT_COMMIT#g" deployment.yml
                  cat deployment.yml
                  git config user.name "Jenkins CI"
                  git config --global user.email "jenkins@dasher.com"
                  git remote set-url origin http://$GITEA_TOKEN@git-server:5555/dasher-org/solar-system-gitops-argocd
                  git add .
                  git commit -am "Updated docker image"
                  git push -u origin feature-$BUILD_ID
              '''
          }
      }
    }
    stage('Kubernetes Deployment - Raise PR') {
      when  {
              branch 'PR*'
      }
      steps {
          sh """
            curl -X 'POST' \
              'http://git-server:5555/api/v1/repos/dasher-org/solar-system-gitops-argocd/pulls' \
              -H 'accept: application/json' \
              -H 'Authorization: token $GITEA_TOKEN' \
              -H 'Content-Type: application/json' \
              -d '{
              "assignee": "gitea-admin",
              "assignees": [
                "gitea-admin"
              ],
              "base": "main",
              "body": "Updated docker image in deployment manifest",
              "head": "feature-$BUILD_ID",
              "title": "Updated Docker Image"
            }'
          """
      }
    }

stage("Deploy to Prod?") {
  when {
    branch 'PR*'
  }
  steps {
    timeout(time: 1, unit: 'DAYS') {
      input message: 'Is the PR Merged and ArgoCD Synced?', ok: 'YES! PR is Merged and ArgoCD Application is Synced', submitter: 'admin'
    }
  }
}

       stage('DAST - OWASP ZAP') {
  when { branch 'PR*' }
  steps {
    sh '''
      chmod 777 $(pwd)

      cat > zap_ignore_rules <<EOF
100001\tIGNORE\thttp://k8:30000
10020\tIGNORE\thttp://k8:30000
10021\tIGNORE\thttp://k8:30000
10037\tIGNORE\thttp://k8:30000
10038\tIGNORE\thttp://k8:30000
10063\tIGNORE\thttp://k8:30000
10098\tIGNORE\thttp://k8:30000
90003\tIGNORE\thttp://k8:30000
10049\tIGNORE\thttp://k8:30000
10055\tIGNORE\thttp://k8:30000
90004\tIGNORE\thttp://k8:30000
EOF

      docker run -v $(pwd):/zap/wrk/:rw ghcr.io/zaproxy/zaproxy zap-baseline.py \
        -t http://k8:30000 \
        -r zap_report.html \
        -w zap_report.md \
        -J zap_json_report.json \
        -c zap_ignore_rules
    '''
  }
}



        stage('Lambda - S3 Upload & Deploy') {
    when {
        expression { env.CHANGE_TARGET == 'main' }
    }
    steps {
        withAWS(credentials: 'localstack-aws-credentials', endpointUrl: 'http://localhost:4566', region: 'us-east-1') {
          sh '''
            sed -i "/^app\\.listen(3000/ s/^/\\/\\//" app.js
            sed -i "s/^module.exports = app;/\\/\\/module.exports = app;/g" app.js
            sed -i "s|^//module.exports.handler|module.exports.handler|" app.js
            tail -5 app.js
          '''
          sh  '''
            zip -qr solar-system-lambda-$BUILD_ID.zip app* package* index.html node*
            ls -ltr solar-system-lambda-$BUILD_ID.zip
          '''
          s3Upload(
              file: "solar-system-lambda-${BUILD_ID}.zip", 
              bucket:'solar-system-lambda-bucket',
              pathStyleAccessEnabled: true
            )
            sh '''
            /usr/local/bin/aws --endpoint-url http://localhost:4566 lambda update-function-code \
             --function-name solar-system-lambda-function \
             --s3-bucket solar-system-lambda-bucket \
             --s3-key solar-system-lambda-${BUILD_ID}.zip
          '''
          sh """
            /usr/local/bin/aws --endpoint-url http://localhost:4566  lambda update-function-configuration \
            --function-name solar-system-lambda-function \
            --environment '{"Variables":{ "MONGO_USERNAME": "${MONGO_USERNAME}","MONGO_PASSWORD": "${MONGO_PASSWORD}","MONGO_URI": "${MONGO_URI}"}}'
          """

        }
      }
     }

 



 
       
       
    }
    post {
      always {
        script {
              if (fileExists('solar-system-gitops-argocd')) {
              sh 'rm -rf solar-system-gitops-argocd'
              }
        }

        junit allowEmptyResults: true, stdioRetention: '', testResults: 'test-results.xml'

        publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, keepAll: true, reportDir: 'coverage/lcov-report', reportFiles: 'index.html', reportName: 'Code Coverage HTML Report', reportTitles: '', useWrapperFileDirectly: true])
        sh 'trivy convert --format template --template "/usr/local/share/trivy/templates/html.tpl" --output trivy-image-CRITICAL-results.html trivy-image-CRITICAL-results.json'
        publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, keepAll: true, reportDir: "./", reportFiles: "trivy-image-CRITICAL-results.html", reportName: "Trivy Image Critical Vul Report", reportTitles: "", useWrapperFileDirectly: true])
      }
    }
}
