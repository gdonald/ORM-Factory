// Runs in the home lab's Jenkins, in one pod with the Raku CI image built from
// raku-ci/ in the devops repo, a Postgres container, and a MySQL container.
// When every stage passes, Jenkins reports the
// continuous-integration/jenkins/branch status, which starts
// .github/workflows/ci.yml on the same commit.

// The CI image's MySQL client library is MariaDB Connector/C. MySQL 8.4
// creates root with caching_sha2_password by default, which over a plain TCP
// connection needs TLS or an RSA key exchange, so root is created with
// mysql_native_password instead.
def buildPod = '''
  apiVersion: v1
  kind: Pod
  spec:
    containers:
      - name: ci
        image: harbor.home.gregdonald.com/raku/ci:latest
        imagePullPolicy: Always
        command: ["sleep"]
        args: ["infinity"]
        resources:
          requests:
            cpu: "2"
            memory: 4Gi
          limits:
            cpu: "4"
            memory: 4Gi
      - name: postgres
        image: postgres:17.11-trixie
        env:
          - name: POSTGRES_USER
            value: postgres
          - name: POSTGRES_PASSWORD
            value: postgres
          - name: POSTGRES_DB
            value: factory_test
        resources:
          requests:
            memory: 512Mi
          limits:
            memory: 1Gi
      - name: mysql
        image: mysql:8.4.13
        args: ["--mysql-native-password=ON", "--authentication-policy=mysql_native_password"]
        env:
          - name: MYSQL_ROOT_PASSWORD
            value: root
          - name: MYSQL_DATABASE
            value: factory_test
        resources:
          requests:
            memory: 1Gi
          limits:
            memory: 2Gi
'''

def postgresUrl = 'postgres://postgres:postgres@localhost:5432/factory_test?schema=public'
def mysqlUrl = 'mysql://root:root@127.0.0.1:3306/factory_test'
def sqliteUrl = 'sqlite:db/test.sqlite3'

pipeline {
  agent {
    kubernetes {
      defaultContainer 'ci'
      yaml buildPod
    }
  }

  options {
    disableConcurrentBuilds(abortPrevious: true)
    timeout(time: 60, unit: 'MINUTES')
  }

  // A failing test stage marks the build failed and the stages after it
  // still run, so one run reports every failure.
  stages {
    // The Postgres and MySQL entrypoints initialize their databases with
    // networking off, then restart listening on their ports.
    stage('dependencies') {
      steps {
        sh 'zef install --/test --force-install https://github.com/gdonald/BDD-Behave.git'
        sh 'zef install --/test --force-install https://github.com/gdonald/ORM-ActiveRecord.git'
        sh 'zef install --/test --test-depends --deps-only .'
        sh "timeout 180 bash -c 'until (exec 3<>/dev/tcp/127.0.0.1/5432) 2>/dev/null; do sleep 2; done'"
        sh "timeout 180 bash -c 'until (exec 3<>/dev/tcp/127.0.0.1/3306) 2>/dev/null; do sleep 2; done'"
      }
    }

    // With no DATABASE_URL, test.raku runs against every adapter it can
    // reach, which here is all three. SQLite matches the GitHub unit job,
    // which has no database servers.
    stage('unit') {
      steps {
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
          withEnv(["DATABASE_URL=${sqliteUrl}"]) {
            sh './test.raku --prove6'
          }
        }
      }
    }

    stage('postgres') {
      steps {
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
          withEnv(["DATABASE_URL=${postgresUrl}"]) {
            sh './test.raku --behave'
          }
        }
      }
    }

    stage('mysql') {
      steps {
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
          withEnv(["DATABASE_URL=${mysqlUrl}"]) {
            sh './test.raku --behave'
          }
        }
      }
    }

    stage('sqlite') {
      steps {
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
          withEnv(["DATABASE_URL=${sqliteUrl}"]) {
            sh './test.raku --behave'
          }
        }
      }
    }
  }
}
