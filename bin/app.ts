#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import * as path from "path";
import * as fs from "fs";
import { BucketDeployment, Source } from "aws-cdk-lib/aws-s3-deployment";
import { Bucket } from 'aws-cdk-lib/aws-s3';
import { DockerImage } from 'aws-cdk-lib';
import { Instance as Ec2Instance, InstanceClass, InstanceSize, InstanceType, IpAddresses, MachineImage, Port, SecurityGroup, SubnetType, UserData, Vpc } from 'aws-cdk-lib/aws-ec2';
import { Platform } from 'aws-cdk-lib/aws-ecr-assets';
import { ManagedPolicy } from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

const app = new cdk.App();
const stack = new cdk.Stack(app, 'kubernetes-cdk-way');

// prepare and deploy assets

const assetsPath = path.join(__dirname, "..", "assets")

const bucket = new Bucket(stack, 'AssetsBucket')
const assetsDeployment = new BucketDeployment(stack, 'DeployAssets', {
  sources: [
    Source.asset(assetsPath, {
      bundling: {
        image: DockerImage.fromBuild(assetsPath),
        platform: Platform.LINUX_ARM64.platform,
      }
    })
  ],
  destinationBucket: bucket,
});

// set up networking

const vpc = new Vpc(stack, 'Vpc', {
  ipAddresses: IpAddresses.cidr("10.0.0.0/27"),
  maxAzs: 1,
})

const securityGroup = new SecurityGroup(stack, "SecurityGroup", {
  vpc
})
securityGroup.connections.allowInternally(Port.allTraffic())

// prepare for creating our instances

const machinesTxt = fs.readFileSync(`${assetsPath}/machines.txt`, "utf8")

const hosts = machinesTxt.split("\n").map(m => {
  const entry = m.split(" ")
  return {
    host: entry[2],
    ip: entry[0],
    cidr: entry[3]
  }
})

interface InstanceProps {
  host: string,
  userData: UserData,
}

class Instance extends Ec2Instance {
  constructor(scope: Construct, id: string, props: InstanceProps) {
    super(scope, id, {
      vpc,
      machineImage: MachineImage.fromSsmParameter("/aws/service/canonical/ubuntu/server/22.04/stable/current/arm64/hvm/ebs-gp2/ami-id"),
      instanceType: InstanceType.of(InstanceClass.T4G, InstanceSize.SMALL),
      securityGroup,
      privateIpAddress: hosts.find(h => h.host === "server")?.ip,
      ...props,
    })
    this.role.addManagedPolicy(ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore"))
    bucket.grantRead(this)
  }
}

const trimLeadingWhitespace = (str: string) => str.replace(/\n[ \t] +/g, "\n").trim()

// configure server instance

const serverUserData = UserData.custom(trimLeadingWhitespace(`
  #!/bin/bash
  set -xe

  bucket=${bucket.bucketName}
  host=server

  ${fs.readFileSync(`${__dirname}/../assets/userdata/common.sh`, "utf8")}
  ${fs.readFileSync(`${__dirname}/../assets/userdata/server.sh`, "utf8")}
  
  # configure routes to other nodes

  ${hosts.filter(r => r.host !== "server")
    .filter(r => r.cidr !== undefined && r.cidr !== "")
    .map(r => `ip route add ${r.cidr} via ${r.ip}`)
    .join("\n")
  }
  `
))

const serverInstance = new Instance(stack, "ServerInstance", {
  host: "server",
  userData: serverUserData,
})
serverInstance.node.addDependency(assetsDeployment)

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

    ${hosts.filter(r => r.host !== host)
      .filter(r => r.cidr !== undefined && r.cidr !== "")
      .map(r => `ip route add ${r.cidr} via ${r.ip}`)
      .join("\n")
    }
    `
  ))
  
  const workerInstance = new Instance(stack, `${host}Instance`, {
    host,
    userData: workerUserData,
  })
  workerInstance.node.addDependency(
    assetsDeployment,
    serverInstance
  )
}

// configure jumpbox instance

const jumpboxUserData = UserData.custom(trimLeadingWhitespace(`
  #!/bin/bash
  set -xe

  bucket=${bucket.bucketName}
  host=jumpbox

  ${fs.readFileSync(`${__dirname}/../assets/userdata/common.sh`, "utf8")}
  ${fs.readFileSync(`${__dirname}/../assets/userdata/jumpbox.sh`, "utf8")}
  `
))

const jumpboxInstance = new Instance(stack, `JumpboxInstance`, {
  host: "jumpbox",
  userData: jumpboxUserData,
})
jumpboxInstance.node.addDependency(
  assetsDeployment,
  serverInstance
)
