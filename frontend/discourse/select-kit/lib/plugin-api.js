import { isNone } from "@ember/utils";
import { makeArray } from "discourse/lib/helpers";

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

let _replaceContentCallbacks = {};
function replaceContent(pluginApiIdentifiers, contentFunction) {
  if (isNone(_replaceContentCallbacks[pluginApiIdentifiers])) {
    _replaceContentCallbacks[pluginApiIdentifiers] = [];
  }

  _replaceContentCallbacks[pluginApiIdentifiers].push(contentFunction);
}

export function applyContentPluginApiCallbacks(content, component) {
  makeArray(component.pluginApiIdentifiers).forEach((key) => {
    (_prependContentCallbacks[key] || []).forEach((c) => {
      const prependedContent = c(component, content);
      if (prependedContent) {
        content = makeArray(prependedContent).concat(content);
      }
    });
    (_appendContentCallbacks[key] || []).forEach((c) => {
      const appendedContent = c(component, content);
      if (appendedContent) {
        content = content.concat(makeArray(appendedContent));
      }
    });

    (_replaceContentCallbacks[key] || []).forEach((c) => {
      const replacementContent = c(component, content);
      if (replacementContent) {
        content = makeArray(replacementContent);
      }
    });
  });

  return content;
}

export function applyOnChangePluginApiCallbacks(value, items, component) {
  makeArray(component.pluginApiIdentifiers).forEach((key) => {
    (_onChangeCallbacks[key] || []).forEach((c) => c(component, value, items));
  });
}

// Whether any prepend/append/replace-content callback is registered for any of the
// given identifiers. Read-only; lets the ui-kit compat bridge skip building a facade
// (and emitting a deprecation) when nothing would fire.
export function hasContentPluginApiCallbacks(identifiers) {
  return makeArray(identifiers).some(
    (key) =>
      _prependContentCallbacks[key]?.length ||
      _appendContentCallbacks[key]?.length ||
      _replaceContentCallbacks[key]?.length
  );
}

// Whether any onChange callback is registered for any of the given identifiers.
export function hasOnChangePluginApiCallbacks(identifiers) {
  return makeArray(identifiers).some((key) => _onChangeCallbacks[key]?.length);
}

/** The plugin or theme that registered each callback, for attributing its deprecation. */
let _callbackSources = new WeakMap();

function sourceKey(source) {
  if (source?.type === "plugin") {
    return `plugin:${source.name}`;
  }
  if (source?.type === "theme") {
    return `theme:${source.id}`;
  }
  return "unattributed";
}

function callbackSources(tables, identifiers) {
  const sources = new Map();
  makeArray(identifiers).forEach((key) => {
    tables.forEach((table) => {
      (table[key] || []).forEach((callback) => {
        const source = _callbackSources.get(callback);
        sources.set(sourceKey(source), source);
      });
    });
  });
  return sources;
}

/**
 * The distinct sources of the content callbacks registered on any of the given identifiers,
 * keyed by a stable string (`plugin:<name>`, `theme:<id>` or `unattributed`).
 *
 * @param {string|string[]} identifiers
 * @returns {Map<string, {type: string, name?: string, id?: number}|undefined>}
 */
export function contentCallbackSources(identifiers) {
  return callbackSources(
    [
      _prependContentCallbacks,
      _appendContentCallbacks,
      _replaceContentCallbacks,
    ],
    identifiers
  );
}

/**
 * Like {@link contentCallbackSources}, for onChange callbacks.
 *
 * @param {string|string[]} identifiers
 * @returns {Map<string, {type: string, name?: string, id?: number}|undefined>}
 */
export function onChangeCallbackSources(identifiers) {
  return callbackSources([_onChangeCallbacks], identifiers);
}

/**
 * @param {string} targetedIdentifier
 * @param {object} [source] - The plugin or theme registering the callbacks, in the shape
 *   `deprecated()` takes as `options.source`.
 */
export function modifySelectKit(targetedIdentifier, source) {
  const register = (add) => (callback) => {
    if (source) {
      _callbackSources.set(callback, source);
    }
    add(targetedIdentifier, callback);
    return modifySelectKit(targetedIdentifier, source);
  };

  return {
    appendContent: register(appendContent),
    prependContent: register(prependContent),
    onChange: register(onChange),
    replaceContent: register(replaceContent),
  };
}

export function clearCallbacks() {
  _appendContentCallbacks = {};
  _prependContentCallbacks = {};
  _onChangeCallbacks = {};
  _replaceContentCallbacks = {};
  _callbackSources = new WeakMap();
}
