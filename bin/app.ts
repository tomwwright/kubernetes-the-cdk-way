#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import * as path from "path";
import * as fs from "fs";
import { BucketDeployment, Source } from "aws-cdk-lib/aws-s3-deployment";
import { Bucket } from 'aws-cdk-lib/aws-s3';
import { DockerImage } from 'aws-cdk-lib';
import { Instance, InstanceClass, InstanceSize, InstanceType, MachineImage, SubnetType, UserData, Vpc } from 'aws-cdk-lib/aws-ec2';
import { Platform } from 'aws-cdk-lib/aws-ecr-assets';
import { ManagedPolicy } from 'aws-cdk-lib/aws-iam';

const app = new cdk.App();
const stack = new cdk.Stack(app, 'kubernetes-cdk-way');

// prepare and deploy assets

const bucket = new Bucket(stack, 'AssetsBucket')

new BucketDeployment(stack, 'DeployAssets', {
  sources: [
    Source.asset(path.join(__dirname, "..", "assets"), {
      bundling: {
        image: DockerImage.fromBuild(path.join(__dirname, "..", 'assets')),
        platform: Platform.LINUX_ARM64.platform,
      }
    })
  ],
  destinationBucket: bucket,
});

// set up networking

const machines = fs.readFileSync(`${__dirname}/../assets/machines.txt`, "utf8")
const ipAddressFor = (machine: string) => {
  const matchingLine = machines
  .split("\n")
  .find(m => m.trim().includes(machine))

  if(!matchingLine)
    throw new Error("Machine not listed in machines.txt")

  return matchingLine.split(" ")[0]
}

const vpc = new Vpc(stack, 'Vpc', {
  cidr: "10.0.0.0/27",
  maxAzs: 1,
})

// configure server instance

const serverUserData = UserData.custom(
  `
  #!/bin/bash

  set -xe

  bucket=${bucket.bucketName}
  host=server

  ${fs.readFileSync(`${__dirname}/../assets/userdata/common.sh`, "utf8")}
  ${fs.readFileSync(`${__dirname}/../assets/userdata/server.sh`, "utf8")}
  `
)

const serverInstance = new Instance(stack, "ServerInstance", {
  vpc,
  machineImage: MachineImage.fromSsmParameter("/aws/service/canonical/ubuntu/server/22.04/stable/current/arm64/hvm/ebs-gp2/ami-id"),
  instanceType: InstanceType.of(InstanceClass.T4G, InstanceSize.SMALL),
  userData: serverUserData,
  privateIpAddress: ipAddressFor("server"),
})
serverInstance.role.addManagedPolicy(ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore"))
bucket.grantRead(serverInstance)
