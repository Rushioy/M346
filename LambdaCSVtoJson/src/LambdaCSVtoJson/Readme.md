# Projekt 346: Lambda Funktion - CSV zu JSON Konvertierungsdienst

## **Projekt Aufbau** ##

### **Ziel**:
Dieses Projekt zielt darauf ab, eine AWS LAmbda Funktion in C# zu implementieren, die CSV-Dateien aus einem S3-Bucket lieest, in JSON-Dateien umwandelt und in einem anderen S3-Bucket speichert. Es dient als praktisches Beispiel, um AWS Lambda,S3, IAM-Berechtigungen und die Automatisierung mit Bash-Skripten zu erlernen.

### Technologie

-AWS S3
-AWS Lambda
-AWS CLI
-Dotnet - C#
-AWS IAM

## Anleitung

### **1. Voraussetzung**

- AWS CLI muss auf dem lokalen Rehcner installiert sein, den musst du bei jeder neu anmeldung unter Credentials ändern.
- AWS Konto haben

### **2. AWS CLI Installation:**
Bitte der Reihe nach eingeben:
sudo apt update
sudo apt install curl

rest von der Anleitung unter: https://gbssg.gitlab.io/m346/iac-aws-cli/

unter .aws muss man bei jedem Start die Datei Credentials neu anpassen. das sieht man auch wenn man unter diesem Link geht.



### **3. C# Lambda-Function
Schritt für Schritt Anleitung:

aws cli: 
Überprüfen Sie, ob die aws cli in der Version >= 2.x.x installiert ist. 
aws --version 

.NET 8 
Prüfen Sie, ob der dotnet sdk 8.0.x installiert ist. 
dotnet --list-sdks 
Falls dotnet sdk 8.0.x nicht aufgelistet wird, installieren sie ihn wie folgt: 
sudo apt-get update 
sudo apt-get install -y dotnet-sdk-8.0 

Amazon Tools 
Installieren Sie die neusten Amazon Lambda Templates: 
dotnet new --install Amazon.Lambda.Templates 

Installieren Sie nun die Amazon Lambda Tools.  
dotnet tool install -g Amazon.Lambda.Tools 

Falls eine Fehlermeldung mitteilt, dass die Tools bereist installiert sind, führen Sie einen Update durch. 
dotnet tool update -g Amazon.Lambda.Tools

Ordnerstruktur:
/aws
└── /M346
    └── /LambdaCSVtoJson
        ├── /src
        │   └── /LambdaCSVtoJson
        │       ├── Function.cs        # Lambda-Funktion
        │       ├── LambdaCSVtoJson.csproj # Projektdatei
        ├── testt.csv                  # Testdatei
        └── init3.sh                   # Skript zur Automatisierung

So sieht meine Ordnerstruktur aus nach dem ALles funktioniert hat. Es hat noch mehr Dateien, aber auf diesen habe ich am meisten gearbeitet.


### ** 4. Implementierung:**

Wichitg als Role LabRole nehmen sonst geht es nicht.
 
Init3.sh:
- Erstellt die Buckets
- Erstellt die Lambda Fuktion
- Erstellt einen S3 Trigger, falls eine Datei im in Bucket ist

### ** 5. Skript ausführen:**
cd ~/aws/M346/LambdaCSVtoJson/src/LambdaCSVtoJson

chmod +x init3.sh

./init3.sh

Das Skript erstellt:

Zwei S3-Buckets (Input und Output).
Eine AWS Lambda-Funktion, die auf neue Objekte im Input-Bucket reagiert.
Eine Benachrichtigungskonfiguration, die die Lambda-Funktion auslöst.

### ** 6. Testen:**
Testdatei hochladen: Laden Sie eine CSV-Datei in den Input-Bucket hoch:
aws s3 cp /home/vmadmin/aws/M346/LambdaCSVtoJson/testt.csv s3://csv-to-json-in-bucket-<Timestamp>

Datei nachschauen ob im in Bucket
aws s3 ls s3://csv-to-json-in-bucket-<Timestamp>

Ausgabe überprüfen: Sehen Sie nach, ob die JSON-Datei im Output-Bucket erstellt wurde:
aws s3 ls s3://csv-to-json-out-bucket-<TIMESTAMP>

Logs prüfen: Überprüfen Sie die Lambda-Ausgabe in den CloudWatch-Logs:

aws logs describe-log-streams --log-group-name "/aws/lambda/CsvToJsonLambda" --order-by LastEventTime --descending
aws logs get-log-events --log-group-name "/aws/lambda/CsvToJsonLambda" --log-stream-nam


## ** 7. Reflexion:**

### **Challenge:**

Meine grösste Herausforderung war die Rolle und dass beim out Bucket das json datei war, ich habe sehr lange ausprobiert. Aber es funktionierte leider nicht. Das war das grösste Problem. 

### **Besser machen:**

Anleitung schon von Anfang an schreiben. Damit man nicht alles nachholen muss. 

### **Zukünftige Verbesserung:**

- Mehr über IAM recherchieren
- Lambda Funktion