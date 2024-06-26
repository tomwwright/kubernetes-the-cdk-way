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

const machinesTxt = fs.readFileSync(`${__dirname}/../assets/machines.txt`, "utf8")

const ipRoutes = machinesTxt.split("\n").map(m => {
  const entry = m.split(" ")
  return {
    machine: entry[2],
    ip: entry[0],
    cidr: entry[3]
  }
}).filter(r => r.cidr !== undefined && r.cidr !== "")

const ipAddressFor = (machine: string) => machinesTxt
  .split("\n")
  .find(m => m.trim().includes(machine))
  ?.split(" ")
  [0]


const vpc = new Vpc(stack, 'Vpc', {
  cidr: "10.0.0.0/27",
  maxAzs: 1,
})

// configure server instance

const trimLeadingWhitespace = (str: string) => str.replace(/\n[ \t] +/g, "\n")

const serverUserData = UserData.custom(trimLeadingWhitespace(`
  #!/bin/bash

  set -xe

  bucket=${bucket.bucketName}
  host=server

  ${fs.readFileSync(`${__dirname}/../assets/userdata/common.sh`, "utf8")}
  ${fs.readFileSync(`${__dirname}/../assets/userdata/server.sh`, "utf8")}
  
  # configure routes to other nodes

  ${ipRoutes.filter(r => r.machine !== "server")
    .map(r => `ip route add ${r.cidr} via ${r.ip}`)
    .join("\n")
  }
  `
))

const serverInstance = new Instance(stack, "ServerInstance", {
  vpc,
  machineImage: MachineImage.fromSsmParameter("/aws/service/canonical/ubuntu/server/22.04/stable/current/arm64/hvm/ebs-gp2/ami-id"),
  instanceType: InstanceType.of(InstanceClass.T4G, InstanceSize.SMALL),
  userData: serverUserData,
  privateIpAddress: ipAddressFor("server"),
})
serverInstance.role.addManagedPolicy(ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore"))
bucket.grantRead(serverInstance)

// configure worker instances

for(const host of ["node-0", "node-1"]) {
  const workerUserData = UserData.custom(trimLeadingWhitespace(`
    #!/bin/bash

    set -xe

    bucket=${bucket.bucketName}
    host=${host}

    ${fs.readFileSync(`${__dirname}/../assets/userdata/common.sh`, "utf8")}
    ${fs.readFileSync(`${__dirname}/../assets/userdata/worker.sh`, "utf8")}
    
    # configure routes to other nodes

    ${ipRoutes.filter(r => r.machine !== host)
      .map(r => `ip route add ${r.cidr} via ${r.ip}`)
      .join("\n")
    }
    `
  ))
  
  const workerInstance = new Instance(stack, `${host}Instance`, {
    vpc,
    machineImage: MachineImage.fromSsmParameter("/aws/service/canonical/ubuntu/server/22.04/stable/current/arm64/hvm/ebs-gp2/ami-id"),
    instanceType: InstanceType.of(InstanceClass.T4G, InstanceSize.SMALL),
    userData: workerUserData,
    privateIpAddress: ipAddressFor(host),
  })
  workerInstance.role.addManagedPolicy(ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore"))
  bucket.grantRead(workerInstance)

}

