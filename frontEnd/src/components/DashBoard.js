import React, { useState, useEffect, useContext } from "react";
import { Row, Col } from "react-bootstrap";
import Archive from "./Archive";
import PaginationTasks from "./PaginationTasks";
import Workers from "./Workers";
import LocaleContext from "../context/LocaleContext";

import "../css/DashBoard.css";

function DashBoard() {

  const {tasksData, archiveData, workersData } = useContext(LocaleContext);

  
  return (
    <div className="DashBoard border pt-4 pb-5 ">
      <div className="ps-4 pe-4">
        <Row>
          <Col sm={8}>
            <PaginationTasks data={tasksData} />
            <Archive get_archive={archiveData} />
          </Col>
          <Col sm={4}>
            <Workers get_workers={workersData} />
          </Col>
        </Row>
      </div>
    </div>
  );
}

export default DashBoard;
