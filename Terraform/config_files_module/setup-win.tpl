@echo off
@REM Deploy the frontend
copy config.js ..\\frontEnd\\src\\config.js
cd ..\\frontEnd
@REM deploy in prod
CALL yarn install
CALL yarn winBuild
@REM Checkout the config.js and copy these command:
CALL aws s3 sync build s3://${S3BUCKET_NAME_WEBSITE}
CALL aws cloudfront create-invalidation --distribution-id ${CLOUDFRONT_DISTRIBUTION_ID} --paths /index.html
@REM Lastly, deploy the python repository:
cd ..
CALL aws s3 sync ec2py s3://${S3BUCKET_EC2APP_REPO}