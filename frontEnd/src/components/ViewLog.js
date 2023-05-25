import React, { useContext, useState, useEffect } from "react";
import Ansi from "ansi-to-react";
import LocaleContext from "../context/LocaleContext";

import "../css/ViewLog.css";

const ViewLog = ({ message, args }) => {
  const { setStateViewLogScreen, setMessage, getData } = useContext(LocaleContext);
  const [activeTab, setActiveTab] = useState("tab1");
  const [timer, setTimer] = useState();

  useEffect(() => {
    setTimer(setInterval(() => {
      getData(setViewLogProps, args)
    }, 30000))
  }, []);

  const closeWindow = (screenState) => {
    setStateViewLogScreen(screenState)
    clearTimeout(timer)
  }

  const handleTab1 = () => {
    // update the state to tab1
    setActiveTab("tab1");
  };
  const handleTab2 = () => {
    // update the state to tab2
    setActiveTab("tab2");
  };

  const setViewLogProps = (data, _args) => {
    setMessage(data);
  };

  const FirstTab = () => {
    return (
      <div className="FirstTab">
         <Ansi>
          {message.logMessage ? message.logMessage.replace(/\r/g, '') : null}
          </Ansi>
      </div>
    );
  };

  const SecondTab = () => {
    return (
      <div className="SecondTab">
        <div dangerouslySetInnerHTML={{__html: message.logMessage}}></div>
      </div>
    );
  };




  return (
    <div className="modal_ViewLog">
        <div className="modal_content">
            <span className="close" onClick={() => closeWindow({seen: false })}>
                close
            </span>
            <span className="close" onClick={() => getData(setViewLogProps, args)}>
                Update
            </span>
            <div>
            <ul className="nav">
              <li
                className={activeTab === "tab1" ? "active" : ""}
                onClick={handleTab1}
              >
                Rendered
              </li>
              <li
                className={activeTab === "tab2" ? "active" : ""}
                onClick={handleTab2}
              >
                Plained
              </li>
            </ul>
            <div className="outlet">
              {activeTab === "tab1" ? <FirstTab /> : <SecondTab />}
            </div>

            </div>
           
        </div>
    </div>
  );
}

export default ViewLog;


