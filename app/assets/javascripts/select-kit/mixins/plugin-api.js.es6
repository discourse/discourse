let _appendContentCallbacks = {};
function appendContent(pluginApiIdentifiers, contentFunction) {
  if (Ember.isNone(_appendContentCallbacks[pluginApiIdentifiers])) {
    _appendContentCallbacks[pluginApiIdentifiers] = [];
  }

  _appendContentCallbacks[pluginApiIdentifiers].push(contentFunction);
}

let _prependContentCallbacks = {};
function prependContent(pluginApiIdentifiers, contentFunction) {
  if (Ember.isNone(_prependContentCallbacks[pluginApiIdentifiers])) {
    _prependContentCallbacks[pluginApiIdentifiers] = [];
  }

  _prependContentCallbacks[pluginApiIdentifiers].push(contentFunction);
}

let _modifyContentCallbacks = {};
function modifyContent(pluginApiIdentifiers, contentFunction) {
  if (Ember.isNone(_modifyContentCallbacks[pluginApiIdentifiers])) {
    _modifyContentCallbacks[pluginApiIdentifiers] = [];
  }

  _modifyContentCallbacks[pluginApiIdentifiers].push(contentFunction);
}

let _onSelectCallbacks = {};
function onSelect(pluginApiIdentifiers, mutationFunction) {
  if (Ember.isNone(_onSelectCallbacks[pluginApiIdentifiers])) {
    _onSelectCallbacks[pluginApiIdentifiers] = [];
  }

  _onSelectCallbacks[pluginApiIdentifiers].push(mutationFunction);
}

export function applyContentPluginApiCallbacks(identifiers, content, context) {
  identifiers.forEach((key) => {
    (_prependContentCallbacks[key] || []).forEach((c) => {
      content = c().concat(content);
    });
    (_appendContentCallbacks[key] || []).forEach((c) => {
      content = content.concat(c());
    });
    (_modifyContentCallbacks[key] || []).forEach((c) => {
      content = c(context, content);
    });
  });

  return content;
}

export function applyOnSelectPluginApiCallbacks(identifiers, val, context) {
  identifiers.forEach((key) => {
    (_onSelectCallbacks[key] || []).forEach((c) => c(context, val));
  });
}

export function modifySelectKit(pluginApiIdentifiers) {
  return {
    appendContent: (content) => {
      appendContent(pluginApiIdentifiers, () => {return content;} );
      return modifySelectKit(pluginApiIdentifiers);
    },
    prependContent: (content) => {
      prependContent(pluginApiIdentifiers, () => {return content;} );
      return modifySelectKit(pluginApiIdentifiers);
    },
    modifyContent: (callback) => {
      modifyContent(pluginApiIdentifiers, callback);
      return modifySelectKit(pluginApiIdentifiers);
    },
    onSelect: (callback) => {
      onSelect(pluginApiIdentifiers, callback);
      return modifySelectKit(pluginApiIdentifiers);
    }
  };
}

export function clearCallbacks() {
  _appendContentCallbacks = {};
  _prependContentCallbacks = {};
  _modifyContentCallbacks = {};
  _onSelectCallbacks = {};
}

const EMPTY_ARRAY = Object.freeze([]);
export default Ember.Mixin.create({
  concatenatedProperties: ["pluginApiIdentifiers"],
  pluginApiIdentifiers: EMPTY_ARRAY
});
