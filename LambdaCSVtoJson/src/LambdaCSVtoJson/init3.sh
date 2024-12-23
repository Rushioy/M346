#!/bin/bash

AWS_REGION="us-east-1"
TIMESTAMP=$(date +%s)
IN_BUCKET="csv-to-json-in-bucket-$TIMESTAMP"
OUT_BUCKET="csv-to-json-out-bucket-$TIMESTAMP"
LAMBDA_NAME="CsvToJsonLambda"
LAMBDA_ROLE_NAME="LabRole"

# Debugging der Bucket-Namen
echo "Debugging: Input Bucket: $IN_BUCKET"
echo "Debugging: Output Bucket: $OUT_BUCKET"

echo "### S3-Buckets erstellen ###"
if [ "$AWS_REGION" == "us-east-1" ]; then
    aws s3api create-bucket --bucket $IN_BUCKET
    if [ $? -ne 0 ]; then
        echo "Fehler: Input-Bucket konnte nicht erstellt werden: $IN_BUCKET"
        exit 1
    fi

    aws s3api create-bucket --bucket $OUT_BUCKET
    if [ $? -ne 0 ]; then
        echo "Fehler: Output-Bucket konnte nicht erstellt werden: $OUT_BUCKET"
        exit 1
    fi
else
    aws s3api create-bucket --bucket $IN_BUCKET --region $AWS_REGION --create-bucket-configuration LocationConstraint=$AWS_REGION
    if [ $? -ne 0 ]; then
        echo "Fehler: Input-Bucket konnte nicht erstellt werden: $IN_BUCKET"
        exit 1
    fi

    aws s3api create-bucket --bucket $OUT_BUCKET --region $AWS_REGION --create-bucket-configuration LocationConstraint=$AWS_REGION
    if [ $? -ne 0 ]; then
        echo "Fehler: Output-Bucket konnte nicht erstellt werden: $OUT_BUCKET"
        exit 1
    fi
fi

echo "### IAM-Rolle verwenden ###"
LAMBDA_ROLE_ARN=$(aws iam get-role --role-name $LAMBDA_ROLE_NAME --query 'Role.Arn' --output text 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Fehler: IAM-Rolle '$LAMBDA_ROLE_NAME' konnte nicht abgerufen werden."
    exit 1
fi

echo "Verwendete IAM-Rolle: $LAMBDA_ROLE_ARN"

echo "### Projekt builden ###"
dotnet publish -c Release --framework net8.0 --runtime linux-x64 --self-contained false -o ./publish
if [ $? -ne 0 ]; then
    echo "Fehler: Projekt konnte nicht gebaut werden."
    exit 1
fi

echo "### ZIP-Datei erstellen ###"
zip -r publish.zip ./publish
if [ $? -ne 0 ]; then
    echo "Fehler: ZIP-Datei konnte nicht erstellt werden."
    exit 1
fi

echo "### ZIP-Datei in S3 hochladen ###"
aws s3 cp ./publish.zip s3://$IN_BUCKET/
if [ $? -ne 0 ]; then
    echo "Fehler: ZIP-Datei konnte nicht in den Input-Bucket hochgeladen werden: $IN_BUCKET"
    exit 1
fi

echo "### Bestehende Lambda-Funktion entfernen ###"
if aws lambda get-function --function-name $LAMBDA_NAME --region $AWS_REGION >/dev/null 2>&1; then
    echo "Lambda-Funktion existiert. Lösche sie..."
    aws lambda delete-function --function-name $LAMBDA_NAME --region $AWS_REGION
    if [ $? -ne 0 ]; then
        echo "Fehler: Bestehende Lambda-Funktion konnte nicht gelöscht werden."
        exit 1
    fi
fi

# Erstellen der Lambda-Funktion
echo "Erstelle neue Lambda-Funktion..."
LAMBDA_ARN=$(aws lambda create-function --function-name $LAMBDA_NAME \
    --runtime dotnet8 \
    --role $LAMBDA_ROLE_ARN \
    --handler CsvToJsonLambda::CsvToJsonLambda.Function::FunctionHandler \
    --timeout 30 \
    --memory-size 256 \
    --code S3Bucket=$IN_BUCKET,S3Key=publish.zip \
    --environment Variables="{DEST_BUCKET=$OUT_BUCKET}" \
    --region $AWS_REGION \
    --query "FunctionArn" --output text)

if [ $? -ne 0 ]; then
    echo "Fehler: Lambda-Funktion konnte nicht erstellt werden."
    exit 1
fi

echo "### S3-Trigger hinzufügen ###"
aws lambda add-permission --function-name $LAMBDA_NAME \
    --statement-id AllowS3Invoke \
    --action "lambda:InvokeFunction" \
    --principal s3.amazonaws.com \
    --source-arn "arn:aws:s3:::$IN_BUCKET"

if [ $? -ne 0 ]; then
    echo "Fehler: Berechtigung für S3-Trigger konnte nicht hinzugefügt werden."
    exit 1
fi

aws s3api put-bucket-notification-configuration --bucket $IN_BUCKET --notification-configuration "{
    \"LambdaFunctionConfigurations\": [
        {
            \"LambdaFunctionArn\": \"$LAMBDA_ARN\",
            \"Events\": [\"s3:ObjectCreated:*\"] 
        }
    ]
}"
if [ $? -ne 0 ]; then
    echo "Fehler: S3-Trigger konnten nicht konfiguriert werden."
    exit 1
fi

echo "### Setup abgeschlossen ###"
echo "Input-Bucket: $IN_BUCKET"
echo "Output-Bucket: $OUT_BUCKET"
