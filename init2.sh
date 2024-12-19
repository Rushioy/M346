DATE=$(date +"%Y%m%d%H%M")
IN_BUCKET="csv-in-bucket-$DATE"
OUT_BUCKET="json-out-bucket-$DATE"
LAMBDA_NAME="csv-to-json-converter-$DATE"
REGION=$(aws configure get region)


# create Lambda Function
cd LambdaCSVtoJson/src/LambdaCSVtoJson
dotnet lambda deploy-function \
    --function-role Labrole \
    --environment-variables OUT_BUCKET=$OUT_BUCKET \
    $LAMBDA_NAME

# Überprüfen, ob csv_to_json.js existiert
if [ ! -f $? ]; then
    echo "Error: lambda not found!"
    exit 1
fi




# S3 Input Bucket erstellen
echo "AWS S3-Input Bucket erstellen..."
aws s3 mb s3://$INPUT_BUCKET --region $REGION

if [ -f $?]; then
    echo "S3- Input Bucket erstellt: $INPUT_BUCKET"

    else 
        echo "S3-Input Bucket wurde nicht erstellt"
    fi






# S3 Output Bucket erstellen
echo "AWS S3-Output Bucket erstellen..."
aws s3 mb s3://$OUTPUT_BUCKET --region $REGION

f [ -f $?]; then
    echo "S3- Output Bucket erstellt: $OUTPUT_BUCKET"

    else 
        echo "S3-Input Bucket wurde nicht erstellt"
    fi

echo "S3 Buckets erfolgreich erstellt: $IN_BUCKET und $OUT_BUCKET"


# trigger erstellen fuer lambda

echo "Ausloesser erstellen fuer $INPUT_BUCKET..."
aws lambda add-permission \
    --function-name $LAMBDA_NAME \
    --statement-id "s3invoke-$DATE" \
    --action "lambda:InvokeFunction" \
    --principal s3.amazonaws.com \
    --source-arn arn:aws:s3:::$INPUT_BUCKET \
    --region $REGION || { echo "Warning: Failed to add Lambda permission"; }


aws s3api put-bucket-notification-configuration \
    --bucket $BUCKET_NAME \
    --notification-configuration "{
        \"LambdaFunctionConfigurations\": [
            {
                \"LambdaFunctionArn\": \"arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$LAMBDA_NAME\",
                \"Events\": [\"s3:ObjectCreated:*\"],
                \"Filter\": {
                    \"Key\": {
                        \"FilterRules\": [
                            { \"Name\": \"suffix\", \"Value\": \".csv\" }
                        ]
                    }
                }
            }
        ]
    }"

#check if trigger is build
f [ -f $?]; then
    echo "Trigger fuer $LAMBDA_NAME erstellt.."

    else 
        echo "Trigger $LAMBDA_NAME wurde nicht erstellt"
    fi