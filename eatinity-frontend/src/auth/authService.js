import {
  AuthenticationDetails,
  CognitoUser,
  CognitoUserAttribute,
} from "amazon-cognito-identity-js";
import { userPool } from "./cognitoConfig";

export function signUp({ name, email, password }) {
  return new Promise((resolve, reject) => {
    const attributes = [
      new CognitoUserAttribute({ Name: "email", Value: email }),
      new CognitoUserAttribute({ Name: "name", Value: name }),
    ];

    userPool.signUp(email, password, attributes, null, (error, result) => {
      if (error) {
        reject(error);
        return;
      }

      resolve(result);
    });
  });
}

export function confirmSignUp({ email, code }) {
  return new Promise((resolve, reject) => {
    const cognitoUser = new CognitoUser({
      Username: email,
      Pool: userPool,
    });

    cognitoUser.confirmRegistration(code, true, (error, result) => {
      if (error) {
        reject(error);
        return;
      }

      resolve(result);
    });
  });
}

export function signIn({ email, password }) {
  return new Promise((resolve, reject) => {
    const authDetails = new AuthenticationDetails({
      Username: email,
      Password: password,
    });

    const cognitoUser = new CognitoUser({
      Username: email,
      Pool: userPool,
    });

    cognitoUser.authenticateUser(authDetails, {
      onSuccess: (session) => {
        resolve({
          user: cognitoUser,
          session,
          idToken: session.getIdToken().getJwtToken(),
          accessToken: session.getAccessToken().getJwtToken(),
          refreshToken: session.getRefreshToken().getToken(),
        });
      },
      onFailure: (error) => {
        reject(error);
      },
      newPasswordRequired: (userAttributes, requiredAttributes) => {
        resolve({
          challenge: "NEW_PASSWORD_REQUIRED",
          user: cognitoUser,
          userAttributes,
          requiredAttributes,
        });
      },
    });
  });
}

export function completeNewPassword({ user, newPassword, userAttributes = {} }) {
  return new Promise((resolve, reject) => {
    user.completeNewPasswordChallenge(newPassword, userAttributes, {
      onSuccess: (session) => {
        resolve({
          user,
          session,
          idToken: session.getIdToken().getJwtToken(),
          accessToken: session.getAccessToken().getJwtToken(),
          refreshToken: session.getRefreshToken().getToken(),
        });
      },
      onFailure: reject,
    });
  });
}

export function signOut() {
  const currentUser = userPool.getCurrentUser();

  if (currentUser) {
    currentUser.signOut();
  }
}

export function getCurrentUserSession() {
  return new Promise((resolve, reject) => {
    const currentUser = userPool.getCurrentUser();

    if (!currentUser) {
      resolve(null);
      return;
    }

    currentUser.getSession((error, session) => {
      if (error) {
        reject(error);
        return;
      }

      if (!session || !session.isValid()) {
        resolve(null);
        return;
      }

      resolve({
        user: currentUser,
        session,
        idToken: session.getIdToken().getJwtToken(),
        accessToken: session.getAccessToken().getJwtToken(),
      });
    });
  });
}

export async function getIdToken() {
  const currentSession = await getCurrentUserSession();
  return currentSession?.idToken || null;
}

export async function getCurrentUserProfile() {
  const currentSession = await getCurrentUserSession();

  if (!currentSession) {
    return null;
  }

  const payload = currentSession.session.getIdToken().payload;

  return {
    userId: payload.sub,
    email: payload.email,
    name: payload.name,
    groups: payload["cognito:groups"] || [],
  };
}
