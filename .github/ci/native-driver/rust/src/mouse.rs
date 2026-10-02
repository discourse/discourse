use crate::protocol::Protocol;
use serde_json::{json, Value};
use std::io;

#[derive(Default)]
pub struct Mouse {
    x: f64,
    y: f64,
    buttons: u64,
    drag: Option<Value>,
}

fn drag_event(protocol: &mut Protocol, session: Option<&str>, kind: &str, x: f64, y: f64, data: Value) -> io::Result<()> {
    protocol.call("Input.dispatchDragEvent", json!({"type": kind, "x": x, "y": y, "data": data}), session)?;
    Ok(())
}

fn move_with_drag_detection(protocol: &mut Protocol, session: Option<&str>, event: Value) -> io::Result<()> {
    let frame = protocol.call("Page.getFrameTree", json!({}), session)?;
    let world = protocol.call("Page.createIsolatedWorld", json!({
        "frameId": frame["frameTree"]["frame"]["id"], "worldName": "native-input-observer"
    }), session)?;
    let context = world["executionContextId"].clone();
    protocol.call("Runtime.evaluate", json!({"contextId": context, "expression": r#"(() => {
        let drag = null;
        let completed = Promise.resolve(false);
        const record = event => { drag = event; };
        const observe = () => {
            window.addEventListener('dragstart', record, {capture: true, once: true});
            completed = new Promise(resolve => setTimeout(() => resolve(!!drag && !drag.defaultPrevented), 0));
        };
        window.addEventListener('mousemove', observe, {capture: true, once: true});
        globalThis.finishNativeDragObservation = async () => {
            const started = await completed;
            window.removeEventListener('mousemove', observe, true);
            window.removeEventListener('dragstart', record, true);
            delete globalThis.finishNativeDragObservation;
            return started;
        };
    })()"#}), session)?;
    protocol.discard_drag_events();
    protocol.call("Input.setInterceptDrags", json!({"enabled": true}), session)?;
    let movement = protocol.call("Input.dispatchMouseEvent", event.clone(), session);
    let observed = protocol.call("Runtime.evaluate", json!({
        "contextId": context, "expression": "globalThis.finishNativeDragObservation()", "awaitPromise": true, "returnByValue": true
    }), session);
    let disabled = protocol.call("Input.setInterceptDrags", json!({"enabled": false}), session);
    movement?;
    let observed = observed?;
    disabled?;
    if observed["result"]["value"] == true {
        let data = protocol.receive_drag(session)?;
        drag_event(protocol, session, "dragEnter", event["x"].as_f64().unwrap(), event["y"].as_f64().unwrap(), data.clone())?;
        protocol.mouse.drag = Some(data);
    }
    Ok(())
}

pub fn move_to(protocol: &mut Protocol, session: Option<&str>, params: &Value) -> io::Result<Value> {
    let x = params["x"].as_f64().ok_or_else(|| io::Error::other("x is required"))?;
    let y = params["y"].as_f64().ok_or_else(|| io::Error::other("y is required"))?;
    let steps = params.get("steps").map_or(Some(1), Value::as_u64)
        .filter(|steps| *steps > 0).ok_or_else(|| io::Error::other("steps must be a positive integer"))?;
    let start_x = protocol.mouse.x;
    let start_y = protocol.mouse.y;
    for step in 1..=steps {
        let current_x = start_x + (x - start_x) * step as f64 / steps as f64;
        let current_y = start_y + (y - start_y) * step as f64 / steps as f64;
        let button = if protocol.mouse.buttons & 1 != 0 { "left" }
            else if protocol.mouse.buttons & 2 != 0 { "right" }
            else if protocol.mouse.buttons & 4 != 0 { "middle" } else { "none" };
        let event = json!({
            "type": "mouseMoved", "x": current_x, "y": current_y,
            "button": button, "buttons": protocol.mouse.buttons, "modifiers": params["modifiers"].as_u64().unwrap_or(0)
        });
        if let Some(data) = protocol.mouse.drag.clone() {
            drag_event(protocol, session, "dragOver", current_x, current_y, data)?;
        } else if button == "left" {
            move_with_drag_detection(protocol, session, event)?;
        } else {
            protocol.call("Input.dispatchMouseEvent", event, session)?;
        }
        protocol.mouse.x = current_x;
        protocol.mouse.y = current_y;
    }
    Ok(json!({}))
}

pub fn button(protocol: &mut Protocol, session: Option<&str>, params: &Value, down: bool) -> io::Result<Value> {
    let button = params["button"].as_str().unwrap_or("left");
    let flag = match button {
        "left" => 1, "right" => 2, "middle" => 4,
        _ => return Err(io::Error::other("Unsupported mouse button")),
    };
    let buttons = if down { protocol.mouse.buttons | flag } else { protocol.mouse.buttons & !flag };
    if !down && button == "left" {
        if let Some(data) = protocol.mouse.drag.take() {
            let (x, y) = (protocol.mouse.x, protocol.mouse.y);
            drag_event(protocol, session, "drop", x, y, data)?;
            protocol.mouse.buttons = buttons;
            return Ok(json!({}));
        }
    }
    protocol.call("Input.dispatchMouseEvent", json!({
        "type": if down { "mousePressed" } else { "mouseReleased" },
        "x": protocol.mouse.x, "y": protocol.mouse.y,
        "button": button, "buttons": buttons, "clickCount": params["clickCount"].as_u64().unwrap_or(1),
        "modifiers": params["modifiers"].as_u64().unwrap_or(0)
    }), session)?;
    protocol.mouse.buttons = buttons;
    Ok(json!({}))
}

pub fn click(protocol: &mut Protocol, session: Option<&str>, params: &Value) -> io::Result<Value> {
    let count = params["clickCount"].as_u64().unwrap_or(1);
    if !(1..=3).contains(&count) {
        return Err(io::Error::other("Unsupported click count"));
    }
    move_to(protocol, session, params)?;
    for click_count in 1..=count {
        let options = json!({"button": params["button"].as_str().unwrap_or("left"), "clickCount": click_count});
        button(protocol, session, &options, true)?;
        button(protocol, session, &options, false)?;
    }
    Ok(json!({}))
}

pub fn reset(protocol: &mut Protocol, session: Option<&str>) -> io::Result<Value> {
    if let Some(data) = protocol.mouse.drag.take() {
        let (x, y) = (protocol.mouse.x, protocol.mouse.y);
        drag_event(protocol, session, "dragCancel", x, y, data)?;
    }
    for (name, flag) in [("left", 1), ("right", 2), ("middle", 4)] {
        if protocol.mouse.buttons & flag != 0 {
            button(protocol, session, &json!({"button": name}), false)?;
        }
    }
    Ok(json!({}))
}

pub fn wheel(protocol: &mut Protocol, session: Option<&str>, params: &Value) -> io::Result<Value> {
    let delta_x = params["deltaX"].as_f64().ok_or_else(|| io::Error::other("deltaX is required"))?;
    let delta_y = params["deltaY"].as_f64().ok_or_else(|| io::Error::other("deltaY is required"))?;
    protocol.call("Input.dispatchMouseEvent", json!({
        "type": "mouseWheel", "x": protocol.mouse.x, "y": protocol.mouse.y,
        "buttons": protocol.mouse.buttons, "deltaX": delta_x, "deltaY": delta_y,
    }), session)
}
