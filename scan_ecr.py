#!/usr/bin/python
"""
Author: Monish Mani
Ojective: This script takes 4 parameters to .
Steps: 1. Pass 4  arguments
       2. Triggers the scan for the image
       3. Waits for the scan to complete
       4. Checks the Scan Status
       5. Creates csv report

Arguments: 1. Environment: Accepted values - uat , prod
           2. Region Name: Accepted values - Virginia, Sydney, Singapore, Tokyo, Ireland, Frankfurt
           3. Repo Name: Repo name as in shown in the AWS  ECR
           4. Image Tag : Image tag Name
"""
import boto3
import sys
import time
import csv
from botocore.exceptions import ClientError
from logging import getLogger, INFO
logger = getLogger()

if len(sys.argv) != 5:
    raise ValueError(
        'Please run the script with 4 arguments: Environment, Region_Name, ECR_Repo_Name, Image_Tag_Name \n UAT_Env: uat \n prod_env: prod \n Region_Name: Virginia, Sydney, Singapore, Tokyo, Ireland, Frankfurt')

Environment = sys.argv[1]
Environment = Environment.lower()
if (Environment == "uat"):
    env = 'non_prod_aws'
elif (Environment == "prod"):
    env = 'default'
else:
    env = 'non_prod_aws'

Region_Name = sys.argv[2]
Region_Name = Region_Name.lower()
if (Region_Name == "virginia"):
    RName = "us-east-1"
elif (Region_Name == "sydney"):
    RName = "ap-southeast-2"
elif (Region_Name == "singapore"):
    RName = "ap-southeast-1"
elif (Region_Name == "tokyo"):
    RName = "ap-northeast-1"
elif (Region_Name == "Ireland"):
    RName = "eu-west-1"
else:
    RName = "eu-central-1"

Repo_Name = sys.argv[3]
Image_Tag_Name = sys.argv[4]


def start_image_scan(env, RName, Repo_Name, Image_Tag_Name):
    try:
        session = boto3.Session(profile_name=env)
        client = session.client('ecr', region_name=RName)
        response = client.start_image_scan(
            repositoryName=Repo_Name,
            imageId={
                'imageTag': Image_Tag_Name
            })
        waiter = client.get_waiter('image_scan_complete')
        waiter.wait(repositoryName=Repo_Name,
                    imageId={
                        'imageTag': Image_Tag_Name
                    },
                    maxResults=123,
                    WaiterConfig={
                        'Delay': 60,
                        'MaxAttempts': 5
                    })
        return response

    except ClientError as err:
        logger.error("Request failed: %s", err.response['Error']['Message'])


def image_scan_status(env, RName, Repo_Name, Image_Tag_Name):
    try:
        session = boto3.Session(profile_name=env)
        client = session.client('ecr', region_name=RName)
        response = client.describe_image_scan_findings(
            repositoryName=Repo_Name,
            imageId={
                'imageTag': Image_Tag_Name
            },
            maxResults=1000)

        return (response['imageScanStatus']['status'])

    except ClientError as err:
        logger.error("Request failed: %s", err.response['Error']['Message'])


def scan_results(env, RName, Repo_Name, Image_Tag_Name, Region_Name):
    try:
        session = boto3.Session(profile_name=env)
        client = session.client('ecr', region_name=RName)
        response = client.describe_image_scan_findings(
            repositoryName=Repo_Name,
            imageId={
                'imageTag': Image_Tag_Name
            },
            maxResults=1000)

        # print (response['imageScanFindings']['findings'][0]['attributes'][3])
        # l=response['imageScanFindings']['findings'][0]['attributes'][3]
        # print ((l["value"]))

        criticalresult = {}
        criticalresultList = []
        findings = response['imageScanFindings']['findings']
        # print type(findings)

        for i in findings:
            severity = i.get('severity', "No Severity").encode('ascii','replace')
            description = i.get('description', 'No Description').encode('ascii','replace')
            uri = i.get('uri', "No Uri").encode('ascii','replace')
            CVE_Name = i.get('name', "No Name").encode('ascii','replace')
            Package_Version = i['attributes'][0]['value']
            Package_Name = i['attributes'][1]['value']
            if len(i['attributes']) == 4:
                CVSS_SCORE = i['attributes'][3]['value']
            else:
                CVSS_SCORE = "NA"
            File_Name = env + "_" + Region_Name + "_" + Repo_Name + "_" + Image_Tag_Name + ".csv"
            with open(File_Name, 'ab') as file:
                fieldnames = ['CVE_Name', 'CVE_uri', 'CVSS2_SCORE', 'Severity', 'Package', 'Package_Version',
                              'Description']
                writer = csv.DictWriter(file, fieldnames=fieldnames)
                if file.tell() == 0:
                    writer.writeheader()

                writer.writerow({'CVE_Name': CVE_Name, 'CVE_uri': uri, 'CVSS2_SCORE': CVSS_SCORE, 'Severity': severity,
                                 'Package': Package_Name, 'Package_Version': Package_Version,
                                 'Description': description})
        print("The csv scan report is created")


    except ClientError as err:
        logger.error("Request failed: %s", err.response['Error']['Message'])


start_image_scan(env, RName, Repo_Name, Image_Tag_Name)
print("The image scan status: " + image_scan_status(env, RName, Repo_Name, Image_Tag_Name))
scan_results(env, RName, Repo_Name, Image_Tag_Name, Region_Name)