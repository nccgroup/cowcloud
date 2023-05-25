export default {

	apiGateway: {
		REGION: '${REGION}', 
		URL: '${URL}prod' 
	},
	cognito: {
		REGION: '${REGION}', 
		USER_POOL_ID: '${USER_POOL_ID}', 
		APP_CLIENT_ID: '${APP_CLIENT_ID}', 
		DOMAIN: '${DOMAIN}', 
		SCOPE: ['phone', 'email', 'profile', 'openid', 'aws.cognito.signin.user.admin'],
		REDIRECT_SIGN_IN: '${REDIRECT_SIGN_IN}', 
		REDIRECT_SIGN_OUT: '${REDIRECT_SIGN_OUT}', 
		RESPONSE_TYPE: 'token'
	}
};

// Sync the new files from the website: aws s3 sync build s3://${S3BUCKET_NAME_WEBSITE}
// # FOR DEBUGGING PURPOSE YOU HAVE TO SEPARATE $ FROM {} IN THE VARIABLE 'CLOUDFRONT_DISTRIBUTION_ID'
// create an invalidation on CloudFront: aws cloudfront create-invalidation --distribution-id ${CLOUDFRONT_DISTRIBUTION_ID} --paths /index.html
// Sync the python repository: aws s3 sync ec2py s3://${S3BUCKET_EC2APP_REPO}