"use strict";

/**
 * Cognito Pre-Token Generation V2 Lambda trigger.
 *
 * Injects `custom:role` from the user's Cognito attributes into the
 * ACCESS TOKEN.  This allows the frontend to use access tokens (standard
 * OAuth) instead of ID tokens for authenticated API requests.
 *
 * Scope: custom:role ONLY.  custom:orgId is intentionally NOT injected
 * (orgId continues to come from the /me DB lookup).
 *
 * Missing-role handling: if the user has no `custom:role` attribute, the
 * Lambda injects an empty string.  The backend middleware (service-common
 * requireAuth) treats empty/missing role as falsy and rejects the request
 * — fail-closed behavior is preserved without a role default.
 */
exports.handler = async (event) => {
  const userAttributes = event.request.userAttributes || {};
  const role = userAttributes["custom:role"] || "";

  if (!role) {
    console.warn(
      JSON.stringify({
        level: "warn",
        msg: "pre-token-generation: user missing custom:role attribute",
        sub: userAttributes.sub,
        email: userAttributes.email,
        triggerSource: event.triggerSource,
      })
    );
  } else {
    console.log(
      JSON.stringify({
        level: "info",
        msg: "pre-token-generation: injecting custom:role into access token",
        sub: userAttributes.sub,
        role,
        triggerSource: event.triggerSource,
      })
    );
  }

  event.response = {
    claimsAndScopeOverrideDetails: {
      accessTokenGeneration: {
        claimsToAddOrOverride: {
          "custom:role": role,
        },
        // No scopes to add or suppress
      },
      // Do NOT modify ID token claims — Cognito handles them natively
    },
  };

  return event;
};
