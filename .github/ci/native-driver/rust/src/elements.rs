use crate::protocol::Protocol;
use serde_json::{json, Value};
use std::io;

fn result_value(result: Value) -> io::Result<Value> {
    if let Some(exception) = result.get("exceptionDetails") {
        return Err(io::Error::other(exception.to_string()));
    }
    Ok(result["result"].clone())
}

fn call_function(protocol: &mut Protocol, session: Option<&str>, object: &str, function: &str, arguments: Value, by_value: bool) -> io::Result<Value> {
    result_value(protocol.call("Runtime.callFunctionOn", json!({
        "objectId": object, "functionDeclaration": function, "arguments": arguments,
        "returnByValue": by_value, "awaitPromise": true
    }), session)?)
}

pub fn find(protocol: &mut Protocol, session: Option<&str>, params: &Value) -> io::Result<Value> {
    let normalize = |value: &Value| -> Value {
        match value.as_str() {
            Some(selector) if matches!(selector.trim_start().chars().next(), Some('>' | '+' | '~')) => json!(format!(":scope {selector}")),
            _ => value.clone(),
        }
    };
    let selector = if params["xpath"].as_bool().unwrap_or(false) { params["selector"].clone() } else { normalize(&params["selector"]) };
    let steps = match params["steps"].as_array() {
        Some(steps) => Value::Array(steps.iter().map(normalize).collect()),
        None => Value::Null,
    };
    let root = match params["objectId"].as_str() {
        Some(root) => root.to_string(),
        None => {
            let mut options = json!({"expression": "document"});
            if params["contextId"].is_number() { options["contextId"] = params["contextId"].clone(); }
            result_value(protocol.call("Runtime.evaluate", options, session)?)?["objectId"]
                .as_str().ok_or_else(|| io::Error::other("Document has no object handle"))?.to_string()
        },
    };
    let matches = call_function(protocol, session, &root,
        r#"function(selector, xpath, steps, pierceShadow) {
            if (!this.isConnected) throw new Error('NativeStaleElement');
            if (steps) return steps.reduce((roots, step) => {
                if (Number.isInteger(step)) return roots.at(step) ? [roots.at(step)] : [];
                return Array.from(new Set(roots.flatMap(root => Array.from(root.querySelectorAll(step)))));
            }, [this]);
            if (!xpath) {
                const query = root => {
                    const matches = Array.from(root.querySelectorAll(selector));
                    if (pierceShadow) {
                        if (root.shadowRoot) matches.push(...query(root.shadowRoot));
                        for (const element of root.querySelectorAll('*')) {
                            if (element.shadowRoot) matches.push(...query(element.shadowRoot));
                        }
                    }
                    return matches;
                };
                return query(this);
            }
            const results = document.evaluate(selector, this, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
            return Array.from({length: results.snapshotLength}, (_, index) => results.snapshotItem(index));
        }"#,
        json!([{ "value": selector }, { "value": params["xpath"].as_bool().unwrap_or(false) }, { "value": steps }, { "value": params["pierceShadow"].as_bool().unwrap_or(false) }]), false)?;
    let array = matches["objectId"].as_str().ok_or_else(|| io::Error::other("Query returned no array handle"))?;
    let properties = protocol.call("Runtime.getProperties", json!({"objectId": array, "ownProperties": true}), session)?;
    protocol.call("Runtime.releaseObject", json!({"objectId": array}), session)?;
    let handles: Vec<Value> = properties["result"].as_array().ok_or_else(|| io::Error::other("No query properties"))?
        .iter().filter(|property| property["name"].as_str().is_some_and(|name| name.parse::<usize>().is_ok()))
        .map(|property| property["value"]["objectId"].clone()).collect();
    Ok(json!(handles))
}

fn pointer_point(protocol: &mut Protocol, session: Option<&str>, object: &str, require_enabled: bool, position: &Value) -> io::Result<Value> {
    call_function(protocol, session, object,
        "function(requireEnabled) { if (!this.isConnected) throw new Error('NativeStaleElement'); if (requireEnabled && (this.matches(':disabled') || this.closest('[aria-disabled=true]'))) throw new Error('NativeElementDisabled'); }", json!([{ "value": require_enabled }]), true)?;
    protocol.call("DOM.scrollIntoViewIfNeeded", json!({"objectId": object}), session)?;
    let point = call_function(protocol, session, object, r#"async function(position) {
        const rect = this.getBoundingClientRect();
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
        if (!this.isConnected) throw new Error('NativeStaleElement');
        const current = this.getBoundingClientRect();
        if (['x', 'y', 'width', 'height'].some(key => rect[key] !== current[key])) throw new Error('NativeElementMoving');
        if (!current.width || !current.height || getComputedStyle(this).visibility !== 'visible') throw new Error('NativeElementHidden');
        if (position) {
            const x = current.left + this.clientLeft + position.x + (position.center ? current.width / 2 : 0);
            const y = current.top + this.clientTop + position.y + (position.center ? current.height / 2 : 0);
            if (x < 0 || y < 0 || x >= innerWidth || y >= innerHeight) throw new Error('NativeElementOutsideViewport');
            const hit = this.getRootNode().elementFromPoint(x, y);
            if (!hit || (hit !== this && !this.contains(hit))) throw new Error('NativeElementCovered');
            return {x, y};
        }
        let inViewport = false;
        const clip = {left: 0, top: 0, right: innerWidth, bottom: innerHeight};
        for (const clipped of [false, true]) {
            if (clipped) {
                for (let ancestor = this.assignedSlot || this.parentElement || this.getRootNode().host;
                     ancestor; ancestor = ancestor.assignedSlot || ancestor.parentElement || ancestor.getRootNode().host) {
                    const style = getComputedStyle(ancestor);
                    if (style.overflowX === 'visible' && style.overflowY === 'visible') continue;
                    const bounds = ancestor.getBoundingClientRect();
                    const scaleX = ancestor.offsetWidth ? bounds.width / ancestor.offsetWidth : 1;
                    const scaleY = ancestor.offsetHeight ? bounds.height / ancestor.offsetHeight : 1;
                    if (style.overflowX !== 'visible') {
                        clip.left = Math.max(clip.left, bounds.left + ancestor.clientLeft * scaleX);
                        clip.right = Math.min(clip.right, bounds.left + (ancestor.clientLeft + ancestor.clientWidth) * scaleX);
                    }
                    if (style.overflowY !== 'visible') {
                        clip.top = Math.max(clip.top, bounds.top + ancestor.clientTop * scaleY);
                        clip.bottom = Math.min(clip.bottom, bounds.top + (ancestor.clientTop + ancestor.clientHeight) * scaleY);
                    }
                }
            }
            for (const fragment of this.getClientRects()) {
                const left = Math.max(clip.left, fragment.left), right = Math.min(clip.right, fragment.right);
                const top = Math.max(clip.top, fragment.top), bottom = Math.min(clip.bottom, fragment.bottom);
                if (left >= right || top >= bottom) continue;
                inViewport = true;
                const x = (left + right) / 2, y = (top + bottom) / 2;
                const hit = this.getRootNode().elementFromPoint(x, y);
                if (hit && (hit === this || this.contains(hit))) return {x, y};
            }
        }
        throw new Error(inViewport ? 'NativeElementCovered' : 'NativeElementOutsideViewport');
    }"#, json!([{ "value": position }]), true)?;
    Ok(point["value"].clone())
}

fn frame_point(protocol: &mut Protocol, session: Option<&str>, object: &str, point: Value, enabled: bool) -> io::Result<Value> {
    if !enabled { return Ok(point); }
    let rect = call_function(protocol, session, object, "function() { return this.getBoundingClientRect().toJSON(); }", json!([]), true)?;
    let model = protocol.call("DOM.getBoxModel", json!({"objectId": object}), session)?;
    let quad = model["model"]["border"].as_array().ok_or_else(|| io::Error::other("Frame element has no box model"))?;
    let left = [0, 2, 4, 6].iter().filter_map(|index| quad[*index].as_f64()).fold(f64::INFINITY, f64::min);
    let top = [1, 3, 5, 7].iter().filter_map(|index| quad[*index].as_f64()).fold(f64::INFINITY, f64::min);
    Ok(json!({
        "x": left + point["x"].as_f64().unwrap() - rect["value"]["x"].as_f64().unwrap(),
        "y": top + point["y"].as_f64().unwrap() - rect["value"]["y"].as_f64().unwrap()
    }))
}

pub fn hover(protocol: &mut Protocol, session: Option<&str>, params: &Value) -> io::Result<Value> {
    let object = params["objectId"].as_str().ok_or_else(|| io::Error::other("objectId is required"))?;
    let point = pointer_point(protocol, session, object, false, &Value::Null)?;
    let point = frame_point(protocol, session, object, point, params["frameCoordinates"].as_bool().unwrap_or(false))?;
    crate::mouse::move_to(protocol, session, &point)
}

pub fn click(protocol: &mut Protocol, session: Option<&str>, params: &Value) -> io::Result<Value> {
    let object = params["objectId"].as_str().ok_or_else(|| io::Error::other("objectId is required"))?;
    let point = pointer_point(protocol, session, object, true, &params["position"])?;
    let point = frame_point(protocol, session, object, point, params["frameCoordinates"].as_bool().unwrap_or(false))?;
    let clicks = params["clickCount"].as_u64().unwrap_or(1);
    if !(1..=2).contains(&clicks) {
        return Err(io::Error::other("Unsupported click count"));
    }
    let guard = call_function(protocol, session, object, r#"function() {
        const target = this;
        const host = this.ownerDocument.defaultView;
        const events = ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click', 'dblclick'];
        let result;
        const listener = event => {
            if (!event.isTrusted) return;
            if (result === undefined) {
                result = !target.isConnected ? 'NativeStaleElement' :
                    event.composedPath().includes(target) ? 'done' : 'NativeElementCovered';
            }
            if (result !== 'done') {
                event.preventDefault();
                event.stopPropagation();
                event.stopImmediatePropagation();
            }
        };
        for (const type of events) host.addEventListener(type, listener, true);
        return { stop() {
            for (const type of events) host.removeEventListener(type, listener, true);
            return result || 'NativeElementNoPointerEvent';
        } };
    }"#, json!([]), false)?;
    let guard_id = guard["objectId"].as_str().ok_or_else(|| io::Error::other("Click guard has no object handle"))?;
    let action = crate::keyboard::with_modifiers(protocol, session, &params["modifiers"], |protocol, modifiers| {
        let mut point = point.clone();
        point["modifiers"] = json!(modifiers);
        crate::mouse::move_to(protocol, session, &point)?;
        for count in 1..=clicks {
            for down in [true, false] {
                crate::mouse::button(protocol, session, &json!({"clickCount": count, "modifiers": modifiers}), down)?;
            }
        }
        Ok(())
    });
    let stopped = call_function(protocol, session, guard_id, "function() { return this.stop(); }", json!([]), true);
    let _ = protocol.call("Runtime.releaseObject", json!({"objectId": guard_id}), session);
    action?;
    match stopped {
        Ok(result) if result["value"] == "done" => {}
        Ok(result) => return Err(io::Error::other(result["value"].as_str().unwrap_or("Click guard returned no result"))),
        Err(error) => {
            let message = error.to_string();
            if !["Cannot find context", "Cannot find object", "Could not find object", "Execution context was destroyed"]
                .iter().any(|text| message.contains(text)) {
                return Err(error);
            }
        }
    }
    Ok(json!({}))
}

pub fn fill(protocol: &mut Protocol, session: Option<&str>, params: &Value) -> io::Result<Value> {
    let object = params["objectId"].as_str().ok_or_else(|| io::Error::other("objectId is required"))?;
    let text = params["text"].as_str().ok_or_else(|| io::Error::other("text is required"))?;
    let direct = params["direct"].as_bool().unwrap_or(false);
    call_function(protocol, session, object, r#"function(direct) {
        if (!this.isConnected) throw new Error('NativeStaleElement');
        if (this.readOnly) throw new Error('NativeElementReadonly');
        if (this.tagName !== 'TEXTAREA' && !(this.tagName === 'INPUT' && ['text', 'search', 'email', 'url', 'tel', 'password', 'number'].includes(this.type))) throw new Error('NativeUnsupportedFillType');
        if (direct) {
            if (this.matches(':disabled') || this.closest('[aria-disabled=true]')) throw new Error('NativeElementDisabled');
            const rect = this.getBoundingClientRect();
            if (!rect.width || !rect.height || getComputedStyle(this).visibility !== 'visible') throw new Error('NativeElementHidden');
            this.focus();
            this.select();
        }
    }"#, json!([{ "value": direct }]), true)?;
    if !direct {
        click(protocol, session, params)?;
        call_function(protocol, session, object, "function() { this.focus(); this.select(); }", json!([]), true)?;
    }
    if text.is_empty() {
        for kind in ["keyDown", "keyUp"] {
            let (key, code) = if direct { ("Delete", 46) } else { ("Backspace", 8) };
            protocol.call("Input.dispatchKeyEvent", json!({"type": kind, "key": key, "code": key, "windowsVirtualKeyCode": code}), session)?;
        }
    } else {
        protocol.call("Input.insertText", json!({"text": text}), session)?;
    }
    Ok(json!({}))
}

fn drag_point(protocol: &mut Protocol, session: Option<&str>, object: &str, position: &Value) -> io::Result<Value> {
    let center = pointer_point(protocol, session, object, false, &Value::Null)?;
    if position.is_null() {
        return Ok(center);
    }
    let result = call_function(protocol, session, object, r#"function(position) {
        const rect = this.getBoundingClientRect();
        return {x: rect.x + this.clientLeft + position.x, y: rect.y + this.clientTop + position.y};
    }"#, json!([{ "value": position }]), true)?;
    Ok(result["value"].clone())
}

pub fn drag_to(protocol: &mut Protocol, session: Option<&str>, params: &Value) -> io::Result<Value> {
    let source = params["objectId"].as_str().ok_or_else(|| io::Error::other("objectId is required"))?;
    let target = params["targetId"].as_str().ok_or_else(|| io::Error::other("targetId is required"))?;
    let delay = params["delayMs"].as_f64().unwrap_or(0.0);
    if !delay.is_finite() || delay < 0.0 {
        return Err(io::Error::other("delay must be nonnegative"));
    }
    let delay = std::time::Duration::from_secs_f64(delay / 1000.0);
    let result = (|| {
        let source_point = drag_point(protocol, session, source, &params["sourcePosition"])?;
        crate::mouse::move_to(protocol, session, &source_point)?;
        crate::mouse::button(protocol, session, &json!({}), true)?;
        let target_point = drag_point(protocol, session, target, &params["targetPosition"])?;
        std::thread::sleep(delay);
        let mut movement = target_point.clone();
        movement["steps"] = params.get("steps").cloned().unwrap_or(json!(6));
        crate::mouse::move_to(protocol, session, &movement)?;
        crate::mouse::move_to(protocol, session, &target_point)?;
        std::thread::sleep(delay);
        crate::mouse::button(protocol, session, &json!({}), false)?;
        std::thread::sleep(delay);
        Ok(json!({}))
    })();
    if result.is_err() {
        let _ = crate::mouse::reset(protocol, session);
    }
    result
}

pub fn scroll(protocol: &mut Protocol, session: Option<&str>, params: &Value) -> io::Result<Value> {
    let object = params["objectId"].as_str().ok_or_else(|| io::Error::other("objectId is required"))?;
    let result = call_function(protocol, session, object, r#"function(options) {
        if (!this.isConnected) throw new Error('NativeStaleElement');
        if (options.target) {
            if (options.location === 'top') this.scrollIntoView(true);
            else if (options.location === 'bottom') this.scrollIntoView(false);
            else if (options.location === 'center') this.scrollIntoView({behavior: 'instant', block: 'center'});
            else throw new Error('Invalid scroll location');
        } else {
            let x = options.x, y = options.y;
            if (options.location) {
                x = 0;
                if (options.location === 'top') y = 0;
                else if (options.location === 'bottom') y = this.scrollHeight;
                else if (options.location === 'center') y = (this.scrollHeight - this.clientHeight) / 2;
                else throw new Error('Invalid scroll location');
            }
            this.scrollTo(x, y);
        }
    }"#, json!([{ "value": params }]), true)?;
    Ok(result["value"].clone())
}

pub fn set_value(protocol: &mut Protocol, session: Option<&str>, params: &Value) -> io::Result<Value> {
    let object = params["objectId"].as_str().ok_or_else(|| io::Error::other("objectId is required"))?;
    let value = params["value"].as_str().ok_or_else(|| io::Error::other("value must be a string"))?;
    let validate = params["validate"].as_bool().unwrap_or(false);
    let result = call_function(protocol, session, object, r#"function(value, validate) {
        if (!this.isConnected) throw new Error('NativeStaleElement');
        if (this.tagName !== 'INPUT' || !['color', 'range', 'date', 'time', 'datetime-local'].includes(this.type)) throw new Error('NativeUnsupportedFillType');
        if (!validate) {
            if (this.readOnly) return false;
            if (document.activeElement !== this) this.focus();
            if (this.value !== value) {
                this.value = value;
                this.dispatchEvent(new InputEvent('input'));
                this.dispatchEvent(new Event('change', { bubbles: true }));
            }
        } else {
            if (this.readOnly) throw new Error('NativeElementReadonly');
            if (this.matches(':disabled')) throw new Error('NativeElementDisabled');
            const rect = this.getBoundingClientRect();
            if (!rect.width || !rect.height || getComputedStyle(this).visibility !== 'visible') throw new Error('NativeElementHidden');
            value = value.trim();
            this.focus();
            this.value = value;
            if (this.value !== value) throw new Error('Malformed value');
            this.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
            this.dispatchEvent(new Event('change', { bubbles: true }));
        }
        return true;
    }"#, json!([{ "value": value }, { "value": validate }]), true)?;
    Ok(result["value"].clone())
}

pub fn set_checked(protocol: &mut Protocol, session: Option<&str>, params: &Value) -> io::Result<Value> {
    let object = params["objectId"].as_str().ok_or_else(|| io::Error::other("objectId is required"))?;
    let checked = params["checked"].as_bool().ok_or_else(|| io::Error::other("checked must be boolean"))?;
    let state = call_function(protocol, session, object, r#"function() {
        if (!this.isConnected) throw new Error('NativeStaleElement');
        if (this.tagName !== 'INPUT' || !['checkbox', 'radio'].includes(this.type)) throw new Error('NativeUnsupportedCheckType');
        return this.checked;
    }"#, json!([]), true)?;
    if state["value"] == checked {
        return Ok(json!({}));
    }
    click(protocol, session, params)?;
    call_function(protocol, session, object, r#"function(checked) {
        if (!this.isConnected) throw new Error('NativeStaleElement');
        if (this.checked !== checked) throw new Error('NativeElementCheckFailed');
    }"#, json!([{ "value": checked }]), true)?;
    Ok(json!({}))
}

pub fn select_option(protocol: &mut Protocol, session: Option<&str>, params: &Value) -> io::Result<Value> {
    let object = params["objectId"].as_str().ok_or_else(|| io::Error::other("objectId is required"))?;
    let result = call_function(protocol, session, object, r#"function() {
        if (!this.isConnected) throw new Error('NativeStaleElement');
        const select = this.closest('select');
        if (this.tagName !== 'OPTION' || !select) throw new Error('NativeUnsupportedOption');
        if (this.matches(':disabled')) return false;
        if (select.disabled || select.closest('[aria-disabled=true]')) throw new Error('NativeElementDisabled');
        const rect = select.getBoundingClientRect();
        if (!rect.width || !rect.height || getComputedStyle(select).visibility !== 'visible') throw new Error('NativeElementHidden');
        this.selected = true;
        select.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
        select.dispatchEvent(new Event('change', { bubbles: true }));
        return true;
    }"#, json!([]), true)?;
    Ok(result["value"].clone())
}
