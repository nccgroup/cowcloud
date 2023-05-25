import React, { useState } from "react";
import Tasks from "./Tasks";

import "../css/PaginationTasks.css";

function PaginationTasks({ data, APIref }) {
  const [currentPage, setCurrentPage] = useState(1);
  const [itemPerPage, setItemPerPage] = useState(15);
  const [pageNumberLimit, setPageNumberLimit] = useState(5);
  const [maxPageNumberLimit, setMaxPageNumberLimit] = useState(5);
  const [minPageNumberLimit, setMinPageNumberLimit] = useState(0);

  let pages = [];
  let currentItems = [];
  if (data) {
    for (let i = 1; i <= Math.ceil(data.length / itemPerPage); i++) {
      pages.push(i);
    }

    const indexOfLastItem = currentPage * itemPerPage;
    const indexOfFirstItem = indexOfLastItem - itemPerPage;
    currentItems = data.slice(indexOfFirstItem, indexOfLastItem);
  }

  const handleClick = (event) => {
    setCurrentPage(Number(event.target.id));
  };

  const handleNextbtn = () => {
    setCurrentPage(currentPage + 1);
    if (currentPage + 1 > maxPageNumberLimit) {
      setMaxPageNumberLimit(maxPageNumberLimit + pageNumberLimit);
      setMinPageNumberLimit(minPageNumberLimit + pageNumberLimit);
    }
  };
  const handlePrevbtn = () => {
    setCurrentPage(currentPage - 1);
    if ((currentPage - 1) % pageNumberLimit === 0) {
      setMaxPageNumberLimit(maxPageNumberLimit - pageNumberLimit);
      setMinPageNumberLimit(minPageNumberLimit - pageNumberLimit);
    }
  };

  let pageIncrementBtn = null;
  if (pages.length > maxPageNumberLimit) {
    pageIncrementBtn = <li onClick={handleNextbtn}>&#8230;</li>;
  }
  let pageDecrementBtn = null;
  if (minPageNumberLimit >= 1) {
    pageDecrementBtn = <li onClick={handlePrevbtn}>&#8230;</li>;
  }

  return (
    <div className="PaginationTasks">
      <label className="taskTitle mb-1">Tasks</label>
      <ul className="pageNumbers">
        {currentPage <= 1 ? (
          false
        ) : (
          <li>
            <button
              onClick={handlePrevbtn}
              disabled={currentPage === [0] ? true : false}
            >
              &#xab;
            </button>
          </li>
        )}
        {pageDecrementBtn}
        {pages.map((number) => {
          if (number < maxPageNumberLimit + 1 && number > minPageNumberLimit) {
            return (
              <li
                key={number}
                id={number}
                onClick={handleClick}
                className={currentPage === number ? "active" : null}
              >
                {number}
              </li>
            );
          } else return null;
        })}
        {pageIncrementBtn}
        {currentPage < [pages.length] ? (
          <li>
            <button
              onClick={handleNextbtn}
              disabled={currentPage === [pages.length - 1] ? true : false}
            >
              &#xbb;
            </button>
          </li>
        ) : (
          false
        )}
      </ul>
      <Tasks currentItems={currentItems} APIref={APIref} />
    </div>
  );
}

export default PaginationTasks;
