import React, { useState, useContext } from "react";
import { Form, Button, Container } from "react-bootstrap";
import LocaleContext from "../context/LocaleContext";
import "../css/NewTask.css";

const NewTask = () => {
  const { user, putData } = useContext(LocaleContext);

  const [gettingMessage, setGettingMessage] = useState();
  const [data, setData] = useState();
  const [textArea, setTextArea] = useState(
    JSON.stringify(
      { domain: "rest.vulnweb.com", email: user.attributes.email },
      null,
      2
    )
  );
  
  const [loading, setLoading] = useState(true);
  const [loadingMessage, setLoadingMessage] = useState();

  const set_new_task_msg = (data) =>{
    setGettingMessage(`TaskID: ${data["taskID"]}\nPassword: ${data["passwd"]}\n${data["s3bucketURL"]}\nMessage: ${data["message"]}`)
  }


  async function put() {
    await putData(set_new_task_msg,{ message: JSON.parse(textArea) });
  }

  function handleSubmit(e) {
    e.preventDefault();
    if (loading) {
      setLoadingMessage("Loading...");
      setTimeout(() => {
        setLoading(false);
        put();
      }, 1000);
    } else return put();
  }

  return (
    <div className="NewTask">
      <Container className="mt-3 border p-4">
        <Form onSubmit={handleSubmit}>
          <Form.Group controlId="exampleForm.ControlTextarea1">
            <Form.Label>Message</Form.Label>
            <Form.Control
              as="textarea"
              onChange={(e) => setTextArea(e.target.value)}
              rows={5}
              defaultValue={textArea}
            />
          </Form.Group>
          <Button variant="primary mt-4 mb-4" type="submit">
            Submit
          </Button>
        </Form>
        <Form.Group controlId="exampleForm.ControlTextarea1">
          <Form.Control
            as="textarea"
            rows={5}
            read-only="true"
            value={loading ? loadingMessage : gettingMessage}
          />
        </Form.Group>
      </Container>
    </div>
  );
};

export default NewTask;
