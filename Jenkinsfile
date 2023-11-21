node {
  stage('SCM') {
    checkout scm
  }
  stage('SonarQube Analysis') {
    def dirpath = "src/"
    def scannerHome = tool 'SonarScanner for MSBuild'
    withSonarQubeEnv() {
      dir(dirpath){
        bat "dotnet ${scannerHome}\\SonarScanner.MSBuild.dll begin /k:\"ally-macgregor-sonarsource_geo-location_AYvs65M5fVPk5wpdf_It\""
        bat "dotnet build"
        bat "dotnet ${scannerHome}\\SonarScanner.MSBuild.dll end"
      }
    }
  }
}

stage("Quality Gate"){
  timeout(time: 1, unit: 'HOURS') { // Just in case something goes wrong, pipeline will be killed after a timeout
    def qg = waitForQualityGate() // Reuse taskId previously collected by withSonarQubeEnv
    if (qg.status != 'OK') {
      error "Pipeline aborted due to quality gate failure: ${qg.status}"
    }
  }
}
