use serde_json::{json, Value};
use std::collections::HashMap;
use std::io::{self, BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

enum Recipient {
    External(Value),
    Internal(Sender<io::Result<Value>>),
}

struct Connection {
    stream: UnixStream,
    sequence: u64,
    pending: HashMap<u64, Recipient>,
    closed: bool,
}

#[derive(Clone)]
pub struct Transport {
    connection: Arc<Mutex<Connection>>,
}

impl Transport {
    fn submit(&self, mut request: Value, recipient: Recipient) -> io::Result<u64> {
        let mut connection = self.connection.lock().map_err(|error| io::Error::other(error.to_string()))?;
        if connection.closed {
            return Err(io::Error::new(io::ErrorKind::BrokenPipe, "Chromium pipe closed"));
        }
        connection.sequence += 1;
        let id = connection.sequence;
        request["id"] = json!(id);
        connection.pending.insert(id, recipient);
        let result = serde_json::to_writer(&mut connection.stream, &request)
            .map_err(io::Error::other)
            .and_then(|_| connection.stream.write_all(&[0]));
        if let Err(error) = result {
            connection.pending.remove(&id);
            return Err(error);
        }
        Ok(id)
    }

    pub fn forward(&self, request: Value) -> io::Result<()> {
        let recipient = Recipient::External(request["id"].clone());
        self.submit(request, recipient)?;
        Ok(())
    }
}

pub struct Protocol {
    pub mouse: crate::mouse::Mouse,
    transport: Transport,
    drags: Receiver<Value>,
}

impl Protocol {
    pub fn new(connection: UnixStream, output: Arc<Mutex<io::Stdout>>) -> io::Result<Self> {
        let reader_connection = connection.try_clone()?;
        let transport = Transport {
            connection: Arc::new(Mutex::new(Connection {
                stream: connection,
                sequence: 0,
                pending: HashMap::new(),
                closed: false,
            })),
        };
        let reader_transport = transport.clone();
        let (drag_sender, drags) = mpsc::channel();
        thread::spawn(move || {
            let result = (|| -> io::Result<()> {
                let mut input = BufReader::new(reader_connection);
                loop {
                    let mut bytes = Vec::new();
                    if input.read_until(0, &mut bytes)? == 0 {
                        return Err(io::Error::new(io::ErrorKind::UnexpectedEof, "Chromium pipe closed"));
                    }
                    bytes.pop();
                    let mut message: Value = serde_json::from_slice(&bytes)?;
                    if let Some(id) = message["id"].as_u64() {
                        let recipient = reader_transport.connection.lock().unwrap().pending.remove(&id);
                        match recipient {
                            Some(Recipient::External(id)) => {
                                message["id"] = id;
                                write_message(&output, &message)?;
                            }
                            Some(Recipient::Internal(sender)) => { let _ = sender.send(Ok(message)); }
                            None => {}
                        }
                    } else {
                        if message["method"] == "Input.dragIntercepted" {
                            let _ = drag_sender.send(message.clone());
                        }
                        write_message(&output, &message)?;
                    }
                }
            })();
            let error = result.unwrap_err().to_string();
            let pending = {
                let mut connection = reader_transport.connection.lock().unwrap();
                connection.closed = true;
                std::mem::take(&mut connection.pending)
            };
            for recipient in pending.into_values() {
                match recipient {
                    Recipient::External(id) => {
                        let _ = write_message(&output, &json!({"id": id, "error": {"message": error}}));
                    }
                    Recipient::Internal(sender) => { let _ = sender.send(Err(io::Error::other(error.clone()))); }
                }
            }
        });
        Ok(Self { transport, drags, mouse: crate::mouse::Mouse::default() })
    }

    pub fn transport(&self) -> Transport {
        self.transport.clone()
    }

    pub fn discard_drag_events(&self) {
        while self.drags.try_recv().is_ok() {}
    }

    pub fn receive_drag(&self, session: Option<&str>) -> io::Result<Value> {
        let deadline = Instant::now() + Duration::from_secs(4);
        loop {
            let event = self.drags.recv_timeout(deadline.saturating_duration_since(Instant::now())).map_err(io::Error::other)?;
            if event["sessionId"].as_str() == session {
                return Ok(event["params"]["data"].clone());
            }
        }
    }

    pub fn call(&mut self, method: &str, params: Value, session: Option<&str>) -> io::Result<Value> {
        let mut request = json!({"method": method, "params": params});
        if let Some(session) = session {
            request["sessionId"] = json!(session);
        }
        let (sender, responses) = mpsc::channel();
        let id = self.transport.submit(request, Recipient::Internal(sender))?;
        let response = responses.recv_timeout(Duration::from_secs(30));
        self.transport.connection.lock().unwrap().pending.remove(&id);
        let response = response.map_err(io::Error::other)??;
        if let Some(error) = response.get("error") {
            return Err(io::Error::other(format!("{method}: {error}")));
        }
        Ok(response["result"].clone())
    }
}

pub fn write_message(output: &Arc<Mutex<io::Stdout>>, message: &Value) -> io::Result<()> {
    let mut output = output.lock().map_err(|error| io::Error::other(error.to_string()))?;
    serde_json::to_writer(&mut *output, message)?;
    output.write_all(b"\n")?;
    output.flush()
}

pub fn dispatch(protocol: &mut Protocol, request: &Value) -> io::Result<Value> {
    let method = request["method"].as_str().ok_or_else(|| io::Error::other("method is required"))?;
    let session = request["sessionId"].as_str();
    let params = request.get("params").cloned().unwrap_or(json!({}));
    match method {
        "Driver.mouseWheel" => crate::mouse::wheel(protocol, session, &params),
        "Driver.mouseMove" => crate::mouse::move_to(protocol, session, &params),
        "Driver.mouseClick" => crate::mouse::click(protocol, session, &params),
        "Driver.mouseDown" => crate::mouse::button(protocol, session, &params, true),
        "Driver.mouseUp" => crate::mouse::button(protocol, session, &params, false),
        "Driver.resetMouse" => crate::mouse::reset(protocol, session),
        "Driver.fill" => crate::elements::fill(protocol, session, &params),
        "Driver.setValue" => crate::elements::set_value(protocol, session, &params),
        "Driver.scroll" => crate::elements::scroll(protocol, session, &params),
        "Driver.dragTo" => crate::elements::drag_to(protocol, session, &params),
        "Driver.find" => crate::elements::find(protocol, session, &params),
        "Driver.click" => crate::elements::click(protocol, session, &params),
        "Driver.hover" => crate::elements::hover(protocol, session, &params),
        "Driver.sendKeys" => crate::keyboard::send_keys(protocol, session, &params),
        "Driver.setChecked" => crate::elements::set_checked(protocol, session, &params),
        "Driver.selectOption" => crate::elements::select_option(protocol, session, &params),
        "Driver.newPage" => {
            let mut options = json!({"url": "about:blank"});
            if params["browserContextId"].is_string() {
                options["browserContextId"] = params["browserContextId"].clone();
            }
            let target = protocol.call("Target.createTarget", options, None)?;
            let attached = protocol.call("Target.attachToTarget", json!({"targetId": target["targetId"], "flatten": true}), None)?;
            Ok(json!({"sessionId": attached["sessionId"], "targetId": target["targetId"], "browserContextId": params["browserContextId"]}))
        }
        "Driver.attachPage" => {
            let info = protocol.call("Target.getTargetInfo", json!({"targetId": params["targetId"]}), None)?;
            let attached = protocol.call("Target.attachToTarget", json!({"targetId": params["targetId"], "flatten": true}), None)?;
            Ok(json!({"sessionId": attached["sessionId"], "targetId": params["targetId"], "browserContextId": info["targetInfo"]["browserContextId"]}))
        }
        "Driver.enablePage" => {
            protocol.call("Page.enable", json!({}), session)?;
            protocol.call("Runtime.enable", json!({}), session)?;
            Ok(json!({}))
        }
        "Driver.evaluate" => {
            let result = protocol.call("Runtime.evaluate", json!({
                "expression": params["expression"], "returnByValue": true, "awaitPromise": true
            }), session)?;
            if let Some(exception) = result.get("exceptionDetails") {
                return Err(io::Error::other(exception.to_string()));
            }
            Ok(result["result"].clone())
        }
        "Driver.clickPoint" => {
            crate::mouse::move_to(protocol, session, &params)?;
            crate::mouse::button(protocol, session, &json!({}), true)?;
            crate::mouse::button(protocol, session, &json!({}), false)
        }
        _ => protocol.call(method, params, session),
    }
}
