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

let _modifyHeaderComputedContentCallbacks = {};
function modifyHeaderComputedContent(pluginApiIdentifiers, contentFunction) {
  if (
    Ember.isNone(_modifyHeaderComputedContentCallbacks[pluginApiIdentifiers])
  ) {
    _modifyHeaderComputedContentCallbacks[pluginApiIdentifiers] = [];
  }

  _modifyHeaderComputedContentCallbacks[pluginApiIdentifiers].push(
    contentFunction
  );
}

let _modifyCollectionHeaderCallbacks = {};
function modifyCollectionHeader(pluginApiIdentifiers, contentFunction) {
  if (Ember.isNone(_modifyCollectionHeaderCallbacks[pluginApiIdentifiers])) {
    _modifyCollectionHeaderCallbacks[pluginApiIdentifiers] = [];
  }

  _modifyCollectionHeaderCallbacks[pluginApiIdentifiers].push(contentFunction);
}

let _onSelectNoneCallbacks = {};
function onSelectNone(pluginApiIdentifiers, mutationFunction) {
  if (Ember.isNone(_onSelectNoneCallbacks[pluginApiIdentifiers])) {
    _onSelectNoneCallbacks[pluginApiIdentifiers] = [];
  }

  _onSelectNoneCallbacks[pluginApiIdentifiers].push(mutationFunction);
}

let _onSelectCallbacks = {};
function onSelect(pluginApiIdentifiers, mutationFunction) {
  if (Ember.isNone(_onSelectCallbacks[pluginApiIdentifiers])) {
    _onSelectCallbacks[pluginApiIdentifiers] = [];
  }

  _onSelectCallbacks[pluginApiIdentifiers].push(mutationFunction);
}

export function applyContentPluginApiCallbacks(identifiers, content, context) {
  identifiers.forEach(key => {
    (_prependContentCallbacks[key] || []).forEach(c => {
      content = c().concat(content);
    });
    (_appendContentCallbacks[key] || []).forEach(c => {
      content = content.concat(c());
    });
    (_modifyContentCallbacks[key] || []).forEach(c => {
      content = c(context, content);
    });
  });

  return content;
}

export function applyHeaderContentPluginApiCallbacks(
  identifiers,
  content,
  context
) {
  identifiers.forEach(key => {
    (_modifyHeaderComputedContentCallbacks[key] || []).forEach(c => {
      content = c(context, content);
    });
  });

  return content;
}

export function applyCollectionHeaderCallbacks(identifiers, content, context) {
  identifiers.forEach(key => {
    (_modifyCollectionHeaderCallbacks[key] || []).forEach(c => {
      content = c(context, content);
    });
  });

  return content;
}

export function applyOnSelectPluginApiCallbacks(identifiers, val, context) {
  identifiers.forEach(key => {
    (_onSelectCallbacks[key] || []).forEach(c => c(context, val));
  });
}

export function applyOnSelectNonePluginApiCallbacks(identifiers, context) {
  identifiers.forEach(key => {
    (_onSelectNoneCallbacks[key] || []).forEach(c => c(context));
  });
}

export function modifySelectKit(pluginApiIdentifiers) {
  return {
    appendContent: content => {
      appendContent(pluginApiIdentifiers, () => {
        return content;
      });
      return modifySelectKit(pluginApiIdentifiers);
    },
    prependContent: content => {
      prependContent(pluginApiIdentifiers, () => {
        return content;
      });
      return modifySelectKit(pluginApiIdentifiers);
    },
    modifyContent: callback => {
      modifyContent(pluginApiIdentifiers, callback);
      return modifySelectKit(pluginApiIdentifiers);
    },
    modifyHeaderComputedContent: callback => {
      modifyHeaderComputedContent(pluginApiIdentifiers, callback);
      return modifySelectKit(pluginApiIdentifiers);
    },
    modifyCollectionHeader: callback => {
      modifyCollectionHeader(pluginApiIdentifiers, callback);
      return modifySelectKit(pluginApiIdentifiers);
    },
    onSelect: callback => {
      onSelect(pluginApiIdentifiers, callback);
      return modifySelectKit(pluginApiIdentifiers);
    },
    onSelectNone: callback => {
      onSelectNone(pluginApiIdentifiers, callback);
      return modifySelectKit(pluginApiIdentifiers);
    }
  };
}

export function clearCallbacks() {
  _appendContentCallbacks = {};
  _prependContentCallbacks = {};
  _modifyContentCallbacks = {};
  _modifyHeaderComputedContentCallbacks = {};
  _modifyCollectionHeaderCallbacks = {};
  _onSelectCallbacks = {};
  _onSelectNoneCallbacks = {};
}

const EMPTY_ARRAY = Object.freeze([]);
export default Ember.Mixin.create({
  concatenatedProperties: ["pluginApiIdentifiers"],
  pluginApiIdentifiers: EMPTY_ARRAY
});
