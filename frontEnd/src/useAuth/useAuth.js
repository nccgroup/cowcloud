import { useState, useEffect, useMemo } from "react";
import Auth from "@aws-amplify/auth";
import API from "@aws-amplify/api";

// eslint-disable-next-line import/no-anonymous-default-export
export default ({ options }) => {
  const [state, setState] = useState({
    user: {},
    isSignedIn: false,
  });

  const APIref = useMemo(() => {
    console.log(options.API)
    API.configure(options.API);
    return API;
  }, []);

  const auth = useMemo(() => {
    Auth.configure(options);
    return Auth;
  }, []);

  useEffect(() => {
    auth
      .currentAuthenticatedUser()
      .then((user) => setState({ user, isSignedIn: true }))
      .catch(() => {});
  }, []);

  const signIn = () => auth.federatedSignIn();

  const signOut = () => auth.signOut();

  return {
    ...state,
    signIn,
    signOut,
    APIref,
  };
};
