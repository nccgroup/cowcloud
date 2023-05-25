import React from "react";
import { Scrollbars } from "react-custom-scrollbars";
import { Table } from "react-bootstrap";
import "../css/Workers.css";

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

const Workers = ({ get_workers }) => {
  if (get_workers !== undefined) {
    return (
      <div className="Workers">
        <label className="workersTitle mb-1">Workers</label>
        <CustomScrollbars autoHide autoHideTimeout={500} autoHideDuration={200}>
          <Table striped bordered hover>
            <thead>
              <tr>
                <th>#</th>
                <th>Worker</th>
                <th>Online</th>
              </tr>
            </thead>
            <tbody>
              {get_workers.map((worker, index) => {
                return (
                  <tr key={index}>
                    <td>{index}</td>
                    <td>{worker.hostname}</td>
                    <td>{worker.online}</td>
                  </tr>
                );
              })}
            </tbody>
          </Table>
        </CustomScrollbars>
      </div>
    );
  } else return null;
};

export default Workers;
