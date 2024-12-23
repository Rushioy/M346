using System;
using System.IO;
using System.Text;
using System.Threading.Tasks;
using Amazon.Lambda.Core;
using Amazon.Lambda.S3Events;
using Amazon.S3;
using CsvHelper;
using Newtonsoft.Json;
using System.Globalization;
using Amazon.Lambda.Serialization.SystemTextJson;

[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace CsvToJsonLambda
{
    public class Function
    {
        private readonly IAmazonS3 _s3Client;

        public Function() : this(new AmazonS3Client()) { }

        public Function(IAmazonS3 s3Client)
        {
            _s3Client = s3Client;
        }

        public async Task FunctionHandler(S3Event evnt, ILambdaContext context)
        {
            var record = evnt.Records?[0].S3;
            if (record == null)
            {
                context.Logger.LogLine("No S3 event record found.");
                return;
            }

            string sourceBucket = record.Bucket.Name;
            string sourceKey = record.Object.Key;

            string destinationBucket = Environment.GetEnvironmentVariable("DEST_BUCKET");
            if (string.IsNullOrEmpty(destinationBucket))
            {
                context.Logger.LogLine("Destination bucket not found in environment variables.");
                return;
            }

            string destinationKey = Path.ChangeExtension(sourceKey, ".json");

            try
            {
                using (var response = await _s3Client.GetObjectAsync(sourceBucket, sourceKey))
                using (var responseStream = response.ResponseStream)
                using (var reader = new StreamReader(responseStream))
                using (var csv = new CsvReader(reader, CultureInfo.InvariantCulture))
                {
                    var records = csv.GetRecords<dynamic>();
                    string jsonContent = JsonConvert.SerializeObject(records, Formatting.Indented);

                    using (var memoryStream = new MemoryStream(Encoding.UTF8.GetBytes(jsonContent)))
                    {
                        var uploadRequest = new Amazon.S3.Model.PutObjectRequest
                        {
                            BucketName = destinationBucket,
                            Key = destinationKey,
                            InputStream = memoryStream,
                            ContentType = "application/json"
                        };

                        await _s3Client.PutObjectAsync(uploadRequest);
                    }
                }

                context.Logger.LogLine($"Successfully converted {sourceKey} to {destinationKey}");
            }
            catch (Exception e)
            {
                context.Logger.LogLine($"Error processing file {sourceKey}: {e.Message}");
                context.Logger.LogLine(e.StackTrace);
                throw;
            }
        }
    }
}
