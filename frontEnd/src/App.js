import React, { useState, useEffect } from "react";
import useAuth from "./useAuth/useAuth";
import config from "./config";
import Auth from "@aws-amplify/auth";
import MainComponent from "./MainComponent";
import LocaleContext from "./context/LocaleContext";
import ViewLog from "../src/components/ViewLog";


import "./App.css";

const App = () => {
  

  const { APIref, signIn, signOut, user, isSignedIn } = useAuth({
    options: {
      mandatorySignIn: true,
      region: config.cognito.REGION,
      userPoolId: config.cognito.USER_POOL_ID,
      userPoolWebClientId: config.cognito.APP_CLIENT_ID,
      oauth: {
        domain:
          config.cognito.DOMAIN +
          ".auth." +
          config.cognito.REGION +
          ".amazoncognito.com",
        scope: config.cognito.SCOPE,
        redirectSignIn: config.cognito.REDIRECT_SIGN_IN,
        redirectSignOut: config.cognito.REDIRECT_SIGN_OUT,
        responseType: config.cognito.RESPONSE_TYPE,
      },
      API: {
        endpoints: [
          {
            name: "scanner",
            endpoint: config.apiGateway.URL,
            region: config.apiGateway.REGION,
            custom_header: async () => {
              //console.log((await Auth.currentSession()).getAccessToken().getJwtToken())
              const test = (await Auth.currentSession())
                .getAccessToken()
                .getJwtToken();
              return { Authorization: "Bearer " + test };
            },
          },
        ],
      },
    },
  });


  
  const putData = async (callback, message) => {
    try {
      const myInit = {
        body: message,
      };
      const data = await APIref.put("scanner", "/putTask", myInit);
      callback(
        data
      );
    } catch (err) {
      console.log("error fetching data..", err);
    }
  };
  
  const [stateViewLogScreen, setStateViewLogScreen] = useState({ seen: false });
  const [message, setMessage] = useState("");
  const [args, setArgs] = useState("");

  const getData = async (callback, _args) => {
    try {
      
      const path = `/getObjects${_args ? _args : ""}`;
      const data = await APIref.get("scanner", path);

      callback(data, _args);
    } catch (err) {
      
      console.log("error fetching data..", err);
      if(String(err).includes("Please authenticate") || String(err).includes("status code 401")){
        // 'The incoming token has expired'
        logOut()
      }
    }
  };

  const [tasksData, setTasksData] = useState();
  const [archiveData, setArchiveData] = useState();
  const [workersData, setWorkersData] = useState();

  const [timer, setTimer] = useState();

  useEffect(() => {
    
      getData(setVariables);
      setTimer(setInterval(() => {
        getData(setVariables);
      }, 60000))
    
    
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const setVariables = (data) => {
    setTasksData(data["tasks"]);
    setArchiveData(data["archive"]);
    setWorkersData(data["workers"]);
  };

  //const navigate = useHistory();
  function refreshPage() {
    //window.location.reload(false);
    getData(setVariables)
  }

  const logOut = () => {
    
    signOut()
    clearTimeout(timer)
    window.location.href = '/';
    //navigate.push('/dashboard')
  }



  
  

  return (
    <div className="App">
      {isSignedIn? (
        
        <LocaleContext.Provider
          value={{
            APIref,
            user,
            getData,
            setStateViewLogScreen,
            setMessage,
            setArgs,
            tasksData,
            archiveData,
            workersData,
            refreshPage,
            putData
          }}
        >
          {stateViewLogScreen.seen ? <ViewLog message={message} args={args}/> : null}
          <div>
            <div className="row">
              <div className="col-8">
                <h5>
                  
                  <i className="fas fa-cloud"></i> Hello {user.username}!
                </h5>
              </div>
              <div className="col-4">
                <button
                  className="btn btn-secondary float-end"
                  onClick={() => logOut()}
                >
                  Logout
                </button>
                <button
                  className="refreshPageBton btn btn-secondary float-end me-1"
                  onClick={() => refreshPage()}
                >Refresh page {" "}{" "}{" "}
                  <i className="fas fa-sync-alt"></i>
                </button>
              </div>
            </div>
            <MainComponent/>
          </div>
        </LocaleContext.Provider>
      ) : (
        <button
          className="btn btn-secondary d-grid mx-auto p-4 mt-5 fs-5"
          onClick={() => signIn()}
        >
          <i className="fas fa-cloud"></i> Login
        </button>
      )}
    </div>
  );
};

export default App;
