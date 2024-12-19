using Amazon.Lambda.Core;
using Amazon.Lambda.S3Events;
using Amazon.S3;
using Amazon.S3.Model;
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using CsvHelper;
using System.Globalization;

[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace CsvToJsonLambda
{
    public class Function
    {
        private readonly IAmazonS3 _s3Client;
        private readonly string outputBucketName = Environment.GetEnvironmentVariable("OUTPUT_BUCKET");

        public Function()
        {
            _s3Client = new AmazonS3Client();
        }

        public Function(IAmazonS3 s3Client)
        {
            _s3Client = s3Client;
        }

        public async Task FunctionHandler(S3Event evnt, ILambdaContext context)
        {
            var record = evnt.Records?[0];
            if (record == null) return;

            string inputBucket = record.S3.Bucket.Name;
            string inputKey = record.S3.Object.Key;

            try
            {
                // CSV-Datei aus dem Input-Bucket lesen
                var getRequest = new GetObjectRequest
                {
                    BucketName = inputBucket,
                    Key = inputKey
                };

                using (var response = await _s3Client.GetObjectAsync(getRequest))
                using (var responseStream = response.ResponseStream)
                using (var reader = new StreamReader(responseStream))
                using (var csv = new CsvReader(reader, CultureInfo.InvariantCulture))
                {
                    // CSV-Daten lesen und in JSON konvertieren
                    var records = csv.GetRecords<dynamic>();
                    string jsonContent = JsonSerializer.Serialize(records, new JsonSerializerOptions { WriteIndented = true });

                    // JSON-Datei im Output-Bucket speichern
                    string outputKey = inputKey.Replace(".csv", ".json");

                    var putRequest = new PutObjectRequest
                    {
                        BucketName = outputBucketName,
                        Key = outputKey,
                        ContentBody = jsonContent,
                        ContentType = "application/json"
                    };

                    await _s3Client.PutObjectAsync(putRequest);
                    context.Logger.LogLine($"Datei erfolgreich konvertiert: {inputKey} -> {outputKey}");
                }
            }
            catch (Exception e)
            {
                context.Logger.LogLine($"Fehler beim Verarbeiten der Datei: {e.Message}");
                throw;
            }
        }
    }
}
