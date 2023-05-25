#!/bin/bash
# I HAVEN'T HAD A CHANCE TO TRY THE SETUP FOR NIX, PLEASE REPORT ANY ISSUE YOU MAY FIND.
# Deploy the frontend
cp config.js ../frontEnd/src/config.js
cd ../frontEnd
# deploy in prod
yarn install
yarn build
# Checkout the config.js and copy these command:
aws s3 sync build s3://${S3BUCKET_NAME_WEBSITE}
aws cloudfront create-invalidation --distribution-id ${CLOUDFRONT_DISTRIBUTION_ID} --paths /index.html
# Lastly, deploy the python repository:
cd ..
aws s3 sync ec2py s3://${S3BUCKET_EC2APP_REPO}