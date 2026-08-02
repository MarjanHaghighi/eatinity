import { CognitoUserPool } from "amazon-cognito-identity-js";

const runtimeConfig = window.__EATINITY_CONFIG__ || {};

const poolData = {
  UserPoolId: runtimeConfig.cognitoUserPoolId || import.meta.env.VITE_COGNITO_USER_POOL_ID,
  ClientId: runtimeConfig.cognitoClientId || import.meta.env.VITE_COGNITO_CLIENT_ID,
};

export const userPool = poolData.UserPoolId && poolData.ClientId
  ? new CognitoUserPool(poolData)
  : null;

export const cognitoConfig = {
  region: runtimeConfig.awsRegion || import.meta.env.VITE_AWS_REGION,
  userPoolId: poolData.UserPoolId,
  clientId: poolData.ClientId,
};
