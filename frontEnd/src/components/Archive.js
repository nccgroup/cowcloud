import React, { useContext } from "react";
import { Scrollbars } from "react-custom-scrollbars";
import { Table } from "react-bootstrap";
import LocaleContext from "../context/LocaleContext";
import "../css/Archive.css";

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

const Archive = ({ get_archive }) => {
  const { getData, setStateViewLogScreen, setMessage, setArgs } =
    useContext(LocaleContext);

  const setViewLogProps = (data, args) => {
    setArgs(args)
    setMessage(data);
    setStateViewLogScreen({
      seen: true,
    });
  };


  // async function put(taskID) {
  //   await putData(setGettingMessage,{ message: taskID });
  // }

  if (get_archive !== undefined) {
    return (
      <div>
        <div className="Archive">
          <label className="archiveTitle mb-1">Archive</label>
          <CustomScrollbars
            autoHide
            autoHideTimeout={500}
            autoHideDuration={200}
          >
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
              <tbody>
                {get_archive.map((archive, index) => {
                  return (
                    <tr key={index}>
                      <td>{index}</td>
                      <td>{archive.taskID}</td>
                      <td>{archive.Worker}</td>
                      <td>{archive.StatusT}</td>
                      <td>
                        <div className="btna">
                          <button
                            onClick={() =>
                              getData(setViewLogProps, `?task=${archive.taskID}`)
                            }
                          >
                            View
                          </button>
                          
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </Table>
          </CustomScrollbars>
        </div>
      </div>
    );
  } else return null;
};

export default Archive;
