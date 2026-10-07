use crate::protocol::Protocol;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::io;
use std::sync::OnceLock;

fn layout() -> &'static HashMap<String, Value> {
    static LAYOUT: OnceLock<HashMap<String, Value>> = OnceLock::new();
    LAYOUT.get_or_init(|| {
        let definitions: Value = serde_json::from_str(include_str!("keyboard-layout.json")).unwrap();
        let mut keys = HashMap::new();
        for (code, definition) in definitions.as_object().unwrap() {
            let key = definition["key"].as_str().unwrap();
            let location = definition["location"].as_u64().unwrap_or(0);
            let description = json!({
                "key": key, "code": code, "location": location,
                "windowsVirtualKeyCode": definition.get("keyCodeWithoutLocation").unwrap_or(&definition["keyCode"]),
                "text": if key.chars().count() == 1 { key } else { definition["text"].as_str().unwrap_or("") }
            });
            let mut physical = description.clone();
            if let Some(shifted_key) = definition["shiftKey"].as_str() {
                let mut shifted = description.clone();
                shifted["key"] = json!(shifted_key);
                shifted["text"] = json!(shifted_key);
                physical["shifted"] = shifted.clone();
                if location == 0 {
                    keys.insert(shifted_key.to_string(), shifted);
                }
            }
            keys.insert(code.clone(), physical);
            if location == 0 && key.chars().count() == 1 {
                keys.insert(key.to_string(), description.clone());
            }
            let aliases: &[&str] = match code.as_str() {
                "ShiftLeft" => &["Shift"], "ControlLeft" => &["Control"],
                "AltLeft" => &["Alt"], "MetaLeft" => &["Meta"],
                "Enter" => &["\n", "\r"], _ => &[],
            };
            for alias in aliases {
                keys.insert(alias.to_string(), description.clone());
            }
        }
        keys
    })
}

fn modifier(key: &str) -> u64 {
    match key { "Alt" => 1, "Control" => 2, "Meta" => 4, "Shift" => 8, _ => 0 }
}

fn key_event(protocol: &mut Protocol, session: Option<&str>, key: &str, modifiers: &mut u64, down: bool) -> io::Result<()> {
    let key = if key == "ControlOrMeta" { "Control" } else { key };
    let original = layout().get(key).ok_or_else(|| io::Error::other(format!("Unknown native key: {key}")))?;
    let mut description = if *modifiers & 8 != 0 { original.get("shifted").unwrap_or(original).clone() } else { original.clone() };
    let flag = modifier(description["key"].as_str().unwrap());
    if down { *modifiers |= flag; } else { *modifiers &= !flag; }
    let fields = description.as_object_mut().unwrap();
    fields.remove("shifted");
    if *modifiers & !8 != 0 { fields.insert("text".into(), json!("")); }
    let text = fields["text"].as_str().unwrap().to_string();
    fields.insert("type".into(), json!(if !down { "keyUp" } else if text.is_empty() { "rawKeyDown" } else { "keyDown" }));
    fields.insert("modifiers".into(), json!(*modifiers));
    if down {
        fields.insert("unmodifiedText".into(), json!(text));
        fields.insert("autoRepeat".into(), json!(false));
        let keypad = fields["location"] == 3;
        fields.insert("isKeypad".into(), json!(keypad));
    } else {
        fields.remove("text");
    }
    protocol.call("Input.dispatchKeyEvent", description, session)?;
    Ok(())
}

pub fn with_modifiers<T>(protocol: &mut Protocol, session: Option<&str>, keys: &Value, action: impl FnOnce(&mut Protocol, u64) -> io::Result<T>) -> io::Result<T> {
    let keys: Vec<&str> = match keys {
        Value::Null => Vec::new(),
        Value::Array(keys) => keys.iter().map(|key| key.as_str()
            .filter(|key| modifier(key) != 0)
            .ok_or_else(|| io::Error::other("Unsupported click modifier"))).collect::<io::Result<_>>()?,
        _ => return Err(io::Error::other("Click modifiers must be an array")),
    };
    let mut modifiers = 0;
    let mut pressed = Vec::new();
    let result = (|| {
        for key in keys {
            if modifiers & modifier(key) == 0 {
                pressed.push(key);
                key_event(protocol, session, key, &mut modifiers, true)?;
            }
        }
        action(protocol, modifiers)
    })();
    let mut release = Ok(());
    for key in pressed {
        if let Err(error) = key_event(protocol, session, key, &mut modifiers, false) {
            if release.is_ok() { release = Err(error); }
        }
    }
    let value = result?;
    release?;
    Ok(value)
}

fn press(protocol: &mut Protocol, session: Option<&str>, combination: &str) -> io::Result<()> {
    let mut tokens = Vec::new();
    let mut token = String::new();
    for character in combination.chars() {
        if character == '+' && !token.is_empty() {
            tokens.push(std::mem::take(&mut token));
        } else {
            token.push(character);
        }
    }
    tokens.push(token);
    for key in &tokens {
        if !layout().contains_key(key) && key != "ControlOrMeta" {
            return Err(io::Error::other(format!("Unknown native key: {key}")));
        }
    }
    let mut modifiers = 0;
    let mut pressed = Vec::new();
    let mut result = Ok(());
    for key in &tokens {
        pressed.push(key);
        if let Err(error) = key_event(protocol, session, key, &mut modifiers, true) {
            result = Err(error);
            break;
        }
    }
    for key in pressed.into_iter().rev() {
        if let Err(error) = key_event(protocol, session, key, &mut modifiers, false) {
            if result.is_ok() { result = Err(error); }
        }
    }
    result
}

pub fn send_keys(protocol: &mut Protocol, session: Option<&str>, params: &Value) -> io::Result<Value> {
    let actions = params["actions"].as_array().ok_or_else(|| io::Error::other("Keyboard actions required"))?;
    for action in actions {
        if let Some(key) = action["press"].as_str() {
            press(protocol, session, key)?;
        } else if let Some(text) = action["type"].as_str() {
            for character in text.chars() {
                let key = character.to_string();
                if layout().contains_key(&key) {
                    press(protocol, session, &key)?;
                } else {
                    protocol.call("Input.insertText", json!({"text": key}), session)?;
                }
            }
        } else {
            return Err(io::Error::other("Unsupported native keyboard action"));
        }
    }
    Ok(json!({}))
}
