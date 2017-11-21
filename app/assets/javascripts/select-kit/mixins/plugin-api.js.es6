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

export function applyContentPluginApiCallbacks(identifiers, content) {
  identifiers.forEach((key) => {
    (_prependContentCallbacks[key] || []).forEach((c) => {
      content = c().concat(content);
    });
    (_appendContentCallbacks[key] || []).forEach((c) => {
      content = content.concat(c());
    });
    (_modifyContentCallbacks[key] || []).forEach((c) => {
      content = c(content);
    });
  });

  return content;
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
    }
  };
}

export function clearCallbacks() {
  _appendContentCallbacks = {};
  _prependContentCallbacks = {};
  _modifyContentCallbacks = {};
}

const EMPTY_ARRAY = Object.freeze([]);
export default Ember.Mixin.create({
  concatenatedProperties: ["pluginApiIdentifiers"],
  pluginApiIdentifiers: EMPTY_ARRAY
});
