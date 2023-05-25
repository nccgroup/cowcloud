import React, { useContext, useState } from "react";
import { Scrollbars } from "react-custom-scrollbars";
import { Table } from "react-bootstrap";

import "../css/Tasks.css";
import LocaleContext from "../context/LocaleContext";

const renderThumb = ({ style, ...props }) => {
  const thumbStyle = {
    borderRadius: 6,
    backgroundColor: "rgba(35, 49, 86, 0.8)",
  };
  return <div style={{ ...style, ...thumbStyle }} {...props} />;
};

const CustomScrollbars = (props) => (
  <Scrollbars
    renderThumbHorizontal={renderThumb}
    renderThumbVertical={renderThumb}
    {...props}
  />
);

const Tasks = ({ currentItems }) => {
  const { getData, putData, setStateViewLogScreen, setMessage, setArgs } =
    useContext(LocaleContext);

  const [gettingMessage, setGettingMessage] = useState();
  
  const confirmationOfInterruption = (data) => {
    //setGettingMessage(data)
    console.log(`Terminating: ${data.taskID}`)
  }

  const setViewLogProps = (data, args) => {
    setArgs(args)
    setMessage(data);
    setStateViewLogScreen({
      seen: true,
    });
  };

  return (
    <div className="Tasks mb-5">
      <CustomScrollbars autoHide autoHideTimeout={500} autoHideDuration={200}>
        <Table striped bordered hover>
          <thead>
            <tr>
              <th>#</th>
              <th>TaskID</th>
              <th>Worker</th>
              <th>Status</th>
              <th>View</th>
            </tr>
          </thead>
          {currentItems.length > 0 ? (
            <tbody>
              {currentItems.map((task, index) => {
                return (
                  <tr key={index}>
                    <td>{index}</td>
                    <td>{task.taskID}</td>
                    <td>{task.Worker}</td>
                    <td>{task.StatusT}</td>
                    <td>
                      <button
                        onClick={() =>
                          getData(setViewLogProps, `?task=${task.taskID}`)
                        }
                      >
                        View
                      </button>
                      <button
                        onClick={() =>
                          putData(confirmationOfInterruption,{ taskID: task.taskID })
                        }
                      >
                        Interrupt
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          ) : null}
        </Table>
      </CustomScrollbars>
    </div>
  );
};

export default Tasks;
