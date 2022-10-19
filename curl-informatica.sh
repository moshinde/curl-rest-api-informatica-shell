DevLoginURL=$1
DevUsername=$2
DevPassword=$3
mappingName=$4
mappingID=$5
DevLogoutURL=$6
echo "****************LOGIN************************"
sessionData=$(curl -X POST ${DevLoginURL} -H "Content-Type: application/json" -d '{"username": "'${DevUsername}'", "password": "'${DevPassword}'"}')
echo "SessionData: $sessionData"
sessionID=$(echo "$sessionData" | jq '.userInfo.sessionId' | sed -e 's/^"//' -e 's/"$//' )
baseApiUrl=$(echo "$sessionData" | jq '.products[].baseApiUrl' | sed -e 's/^"//' -e 's/"$//' )
echo "SessionID: $sessionID"
echo "BaseApiUrl: $baseApiUrl"
echo "${baseApiUrl}/public/core/v3/export"
echo "****************EXPORTING************************"
exportProcess=$(curl -X POST ${baseApiUrl}/public/core/v3/export -H "INFA-SESSION-ID: ${sessionID}" -H "Content-type: application/json" --data-binary '{"name" : "'${mappingName}'","objects" : [{"id": "'${mappingID}'","includeDependencies" : true}]}')
echo "exportProcess=$exportProcess"
runID=$(echo "$exportProcess" | jq '.id' | sed -e 's/^"//' -e 's/"$//')
echo "runID: $runID"
echo "****************WAIT FOR EXPORT TO COMPLETE*************"
check=10
while [[ $check -ge 1 ]]
do
    sleep 20
    echo "Waiting for job run $runID to complete, sleep for 20 seconds"
    getStatus=$(curl -X GET ${baseApiUrl}/public/core/v3/export/${runID} -H "INFA-SESSION-ID: ${sessionID}" -H "Content-type: application/json")
    runStatus=$(echo "$getStatus" | jq '.status.state'| sed -e 's/^"//' -e 's/"$//')
    echo "runStatus: $runStatus"
    case "$runStatus" in
        "PROGRESS")
            continue;;
        "FAILED")
            echo "Run $runID is in $runStatus"
            exit 1;;
        "SUCCESSFUL")
            echo "Run $runID is in $runStatus state"
            break;;
    esac
done
    echo "Export is complete"
echo "****************DOWNLOAD EXPORTED FILE*************"
curl -X GET ${baseApiUrl}/public/core/v3/export/${runID}/package -H "INFA-SESSION-ID: ${sessionID}" -H "Content-type: application/zip" --output exported_${runID}.zip
imprtedPackage=$(curl -X POST ${baseApiUrl}/public/core/v3/import/package -H "INFA-SESSION-ID: ${sessionID}" -H "Content-Type: multipart/form-data" -F package=@exported_${runID}.zip)
echo "imprtedPackage=$imprtedPackage"
jobID=$(echo "$imprtedPackage" | jq '.jobId' | sed -e 's/^"//' -e 's/"$//' )
echo "jobID=$jobID"
importedJob=$(curl -X GET ${baseApiUrl}/public/core/v3/import/${jobID} -H "INFA-SESSION-ID: ${sessionID}" -H "Content-Type: application/json")
echo "importedJob=$importedJob"
importProcessName=$(echo "$importedJob" | jq '.name' | sed -e 's/^"//' -e 's/"$//' )
echo "importProcessName=$importProcessName"
importedJobProgress=$(curl -X POST ${baseApiUrl}/public/core/v3/import/${jobID} -H "INFA-SESSION-ID: ${sessionID}" -H "Content-type: application/json" --data-binary '{"name" : "'${importProcessName}'"}')
echo "importedJobProgress=$importedJobProgress"

importStatus=$(echo "$importedJobProgress" | jq '.status.state' | sed -e 's/^"//' -e 's/"$//' )
echo "importStatus=$importStatus"

check=10
while [[ $check -ge 1 ]]
do
    sleep 20
    echo "Waiting for IMPORT job process $importProcessName to complete, sleep for 20 seconds"
    getImportStatus=$(curl -X GET ${baseApiUrl}/public/core/v3/import/${jobID} -H "INFA-SESSION-ID: ${sessionID}" -H "Content-Type: application/json")
    processStatus=$(echo "$getImportStatus" | jq '.status.state'| sed -e 's/^"//' -e 's/"$//')
    echo "processStatus: $processStatus"
    case "$processStatus" in
        "IN_PROGRESS")
            continue;;
        "FAILED")
            echo "Process $importProcessName is in $processStatus"
            exit 1;;
        "SUCCESSFUL")
            echo "Process $importProcessName is in $processStatus state"
            break;;
    esac
done

echo "Done with importing"
echo "****************LOGGING OUT*************"
curl -X POST ${DevLogoutURL} -H "Content-Type: application/json" -H "INFA-SESSION-ID: ${sessionID}"
