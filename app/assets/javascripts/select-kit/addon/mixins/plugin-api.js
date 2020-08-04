import Mixin from "@ember/object/mixin";
import { isNone } from "@ember/utils";
import { makeArray } from "discourse-common/lib/helpers";

let _appendContentCallbacks = {};
function appendContent(pluginApiIdentifiers, contentFunction) {
  if (isNone(_appendContentCallbacks[pluginApiIdentifiers])) {
    _appendContentCallbacks[pluginApiIdentifiers] = [];
  }

  _appendContentCallbacks[pluginApiIdentifiers].push(contentFunction);
}

let _prependContentCallbacks = {};
function prependContent(targetedIdentifier, contentFunction) {
  if (isNone(_prependContentCallbacks[targetedIdentifier])) {
    _prependContentCallbacks[targetedIdentifier] = [];
  }

  _prependContentCallbacks[targetedIdentifier].push(contentFunction);
}

let _onChangeCallbacks = {};
function onChange(pluginApiIdentifiers, mutationFunction) {
  if (isNone(_onChangeCallbacks[pluginApiIdentifiers])) {
    _onChangeCallbacks[pluginApiIdentifiers] = [];
  }

  _onChangeCallbacks[pluginApiIdentifiers].push(mutationFunction);
}

export function applyContentPluginApiCallbacks(content, component) {
  makeArray(component.pluginApiIdentifiers).forEach(key => {
    (_prependContentCallbacks[key] || []).forEach(c => {
      const prependedContent = c(component, content);
      if (prependedContent) {
        content = makeArray(prependedContent).concat(content);
      }
    });
    (_appendContentCallbacks[key] || []).forEach(c => {
      const appendedContent = c(component, content);
      if (appendedContent) {
        content = content.concat(makeArray(appendedContent));
      }
    });
  });

  return content;
}

export function applyOnChangePluginApiCallbacks(value, items, component) {
  makeArray(component.pluginApiIdentifiers).forEach(key => {
    (_onChangeCallbacks[key] || []).forEach(c => c(component, value, items));
  });
}

export function modifySelectKit(targetedIdentifier) {
  return {
    appendContent: callback => {
      appendContent(targetedIdentifier, callback);
      return modifySelectKit(targetedIdentifier);
    },
    prependContent: callback => {
      prependContent(targetedIdentifier, callback);
      return modifySelectKit(targetedIdentifier);
    },
    onChange: callback => {
      onChange(targetedIdentifier, callback);
      return modifySelectKit(targetedIdentifier);
    }
  };
}

export function clearCallbacks() {
  _appendContentCallbacks = {};
  _prependContentCallbacks = {};
  _onChangeCallbacks = {};
}

const EMPTY_ARRAY = Object.freeze([]);
export default Mixin.create({
  concatenatedProperties: ["pluginApiIdentifiers"],
  pluginApiIdentifiers: EMPTY_ARRAY
});
