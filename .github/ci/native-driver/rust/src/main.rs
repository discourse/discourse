mod protocol;
mod elements;
mod keyboard;
mod mouse;

use serde_json::{json, Value};
use std::io::{self, BufRead};
use std::sync::{Arc, Mutex};
use std::os::fd::AsRawFd;
use std::os::unix::net::UnixStream;
use std::os::unix::process::CommandExt;
use std::process::{Command, Stdio};

fn main() -> io::Result<()> {
    let mut arguments = std::env::args_os().skip(1);
    let executable = arguments.next().ok_or_else(|| {
        io::Error::new(io::ErrorKind::InvalidInput, "Chromium executable is required")
    })?;
    let (connection, browser_connection) = UnixStream::pair()?;
    let browser_fd = browser_connection.as_raw_fd();
    let mut command = Command::new(executable);
    command.args(arguments).arg("--remote-debugging-pipe");
    command.stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::inherit());
    command.process_group(0);
    unsafe {
        command.pre_exec(move || {
            for target in [3, 4] {
                if libc::dup2(browser_fd, target) == -1 || libc::fcntl(target, libc::F_SETFD, 0) == -1 {
                    return Err(io::Error::last_os_error());
                }
            }
            Ok(())
        });
    }
    let mut browser = command.spawn()?;
    drop(browser_connection);
    let output = Arc::new(Mutex::new(io::stdout()));
    let mut protocol = protocol::Protocol::new(connection, output.clone())?;
    let transport = protocol.transport();
    let (sender, requests) = std::sync::mpsc::channel::<Value>();
    let worker_output = output.clone();
    let worker = std::thread::spawn(move || -> io::Result<()> {
        for request in requests {
            let result = protocol::dispatch(&mut protocol, &request);
            let response = match result {
                Ok(result) => json!({"id": request["id"], "result": result}),
                Err(error) => json!({"id": request["id"], "error": {"message": error.to_string()}}),
            };
            protocol::write_message(&worker_output, &response)?;
        }
        Ok(())
    });
    let input_result = (|| -> io::Result<()> {
        for line in io::stdin().lock().lines() {
            let request: Value = serde_json::from_str(&line?)?;
            if request["method"].as_str().is_some_and(|method| method.starts_with("Driver.")) {
                sender.send(request).map_err(io::Error::other)?;
            } else if let Err(error) = transport.forward(request.clone()) {
                protocol::write_message(&output, &json!({"id": request["id"], "error": {"message": error.to_string()}}))?;
            }
        }
        Ok(())
    })();
    drop(sender);
    unsafe {
        libc::kill(-(browser.id() as i32), libc::SIGTERM);
    }
    let _ = browser.wait();
    let _ = worker.join();
    input_result
}
