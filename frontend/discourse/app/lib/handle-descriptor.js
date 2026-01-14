import { computed, get } from "@ember/object";
import CoreObject from "@ember/object/core";
import extractValue from "./extract-value";

export default function handleDescriptor(target, key, desc, params = []) {
  const val = extractValue(desc);

  if (typeof val === "function" && target instanceof CoreObject) {
    // We're in a native class, so convert the method to a getter first
    desc.writable = false;
    desc.initializer = undefined;
    desc.value = undefined;
    desc.get = callUserSuppliedGet(params, val);

    return computed(...params)(target, key, desc);
  } else {
    return {
      enumerable: desc.enumerable,
      configurable: desc.configurable,
      writable: desc.writable,
      initializer() {
        let computedDescriptor;

        if (desc.writable) {
          if (typeof val === "object") {
            let value = {};
            if (val.get) {
              value.get = callUserSuppliedGet(params, val.get);
            }
            if (val.set) {
              value.set = callUserSuppliedSet(params, val.set);
            }
            computedDescriptor = value;
          } else {
            computedDescriptor = callUserSuppliedGet(params, val);
          }
        } else {
          throw new Error(
            "ember-computed-decorators does not support using getters and setters"
          );
        }

        return computed.apply(null, params.concat(computedDescriptor));
      },
    };
  }
}

function niceAttr(attr) {
  const parts = attr.split(".");
  let i;

  for (i = 0; i < parts.length; i++) {
    if (parts[i] === "@each" || parts[i] === "[]" || parts[i].includes("{")) {
      break;
    }
  }

  return parts.slice(0, i).join(".");
}

function callUserSuppliedGet(params, func) {
  params = params.map(niceAttr);
  return function () {
    let paramValues = params.map((p) => get(this, p));

    return func.apply(this, paramValues);
  };
}

function callUserSuppliedSet(params, func) {
  params = params.map(niceAttr);
  return function (key, value) {
    let paramValues = params.map((p) => get(this, p));
    paramValues.unshift(value);

    return func.apply(this, paramValues);
  };
}
