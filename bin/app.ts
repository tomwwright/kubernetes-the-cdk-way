#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import * as path from "path";
import { BucketDeployment, Source } from "aws-cdk-lib/aws-s3-deployment";
import { Bucket } from 'aws-cdk-lib/aws-s3';
import { DockerImage } from 'aws-cdk-lib';
import { Platform } from 'aws-cdk-lib/aws-ecr-assets';

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