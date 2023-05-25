import React, { useContext} from "react";
import NewTask from "./components/NewTask";
import DashBoard from "./components/DashBoard";
import { Tab, Tabs } from "react-bootstrap";
//import LocaleContext from "./context/LocaleContext";
import "./css/MainComponent.css";
import LocaleContext from "./context/LocaleContext";

const MainComponent = () => {

  const {refreshPage } = useContext(LocaleContext);

  return (
    <Tabs
      defaultActiveKey="Dashboard"
      transition={false}
      id="noanim-tab-example"
      
      onSelect={(k) => (k==='Dashboard' ? refreshPage():null)}
    >
      <Tab eventKey="Dashboard" title="Dashboard" className="nav-link" >
        <DashBoard />
      </Tab>
      <Tab eventKey="New Task" title="New Task" className="nav-link">
        <NewTask />
      </Tab>
    </Tabs>
  );
};
export default MainComponent;
