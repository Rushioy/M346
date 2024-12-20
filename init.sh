DATE=$(date +"%Y%m%d%H%M")
IN_BUCKET="csv-in-bucket-$DATE"
OUT_BUCKET="json-out-bucket-$DATE"
LAMBDA_NAME="csv-to-json-converter-$DATE"
REGION=$(aws configure get region)
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Create Lambda Function
cd LambdaCSVtoJson/src/LambdaCSVtoJson
dotnet lambda deploy-function \
    --function-role Labrole \
    --environment-variables OUT_BUCKET=$OUT_BUCKET \
    $LAMBDA_NAME || { echo "Error: Failed to deploy Lambda function"; exit 1; }

# Check if Lambda script exists
if [ ! -f "csv_to_json.js" ]; then
    echo "Error: lambda not found!"
    exit 1
fi

# Create S3 Input Bucket
echo "AWS S3 Input Bucket erstellen..."
aws s3 mb s3://$IN_BUCKET --region $REGION || { echo "Error: Failed to create input bucket"; exit 1; }

echo "S3 Input Bucket erstellt: $IN_BUCKET"

# Create S3 Output Bucket
echo "AWS S3 Output Bucket erstellen..."
aws s3 mb s3://$OUT_BUCKET --region $REGION || { echo "Error: Failed to create output bucket"; exit 1; }

echo "S3 Output Bucket erstellt: $OUT_BUCKET"

echo "S3 Buckets erfolgreich erstellt: $IN_BUCKET und $OUT_BUCKET"

# Add Lambda Trigger
echo "Ausloeser erstellen fuer $IN_BUCKET..."
aws lambda add-permission \
    --function-name $LAMBDA_NAME \
    --statement-id "s3invoke-$DATE" \
    --action "lambda:InvokeFunction" \
    --principal s3.amazonaws.com \
    --source-arn arn:aws:s3:::$IN_BUCKET \
    --region $REGION || { echo "Warning: Failed to add Lambda permission"; }

aws s3api put-bucket-notification-configuration \
    --bucket $IN_BUCKET \
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
    }" || { echo "Error: Failed to configure bucket notification"; exit 1; }

if [ $? -eq 0 ]; then
    echo "Trigger fuer $LAMBDA_NAME erstellt."
else 
    echo "Trigger $LAMBDA_NAME wurde nicht erstellt."
    exit 1
fi
