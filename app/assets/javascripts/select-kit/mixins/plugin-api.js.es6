import Mixin from "@ember/object/mixin";
import { isNone } from "@ember/utils";

let _appendContentCallbacks = {};
function appendContent(pluginApiIdentifiers, contentFunction) {
  if (isNone(_appendContentCallbacks[pluginApiIdentifiers])) {
    _appendContentCallbacks[pluginApiIdentifiers] = [];
  }

  _appendContentCallbacks[pluginApiIdentifiers].push(contentFunction);
}

let _prependContentCallbacks = {};
function prependContent(pluginApiIdentifiers, contentFunction) {
  if (isNone(_prependContentCallbacks[pluginApiIdentifiers])) {
    _prependContentCallbacks[pluginApiIdentifiers] = [];
  }

  _prependContentCallbacks[pluginApiIdentifiers].push(contentFunction);
}

let _filterContentCallbacks = {};
function filterContent(pluginApiIdentifiers, contentFunction) {
  if (isNone(_filterContentCallbacks[pluginApiIdentifiers])) {
    _filterContentCallbacks[pluginApiIdentifiers] = [];
  }

  _filterContentCallbacks[pluginApiIdentifiers].push(contentFunction);
}

let _modifyContentCallbacks = {};
function modifyContent(pluginApiIdentifiers, contentFunction) {
  if (isNone(_modifyContentCallbacks[pluginApiIdentifiers])) {
    _modifyContentCallbacks[pluginApiIdentifiers] = [];
  }

  _modifyContentCallbacks[pluginApiIdentifiers].push(contentFunction);
}

let _modifyHeaderComputedContentCallbacks = {};
function modifyHeaderComputedContent(pluginApiIdentifiers, contentFunction) {
  if (isNone(_modifyHeaderComputedContentCallbacks[pluginApiIdentifiers])) {
    _modifyHeaderComputedContentCallbacks[pluginApiIdentifiers] = [];
  }

  _modifyHeaderComputedContentCallbacks[pluginApiIdentifiers].push(
    contentFunction
  );
}

let _modifyNoSelectionCallbacks = {};
function modifyNoSelection(pluginApiIdentifiers, contentFunction) {
  if (isNone(_modifyNoSelectionCallbacks[pluginApiIdentifiers])) {
    _modifyNoSelectionCallbacks[pluginApiIdentifiers] = [];
  }

  _modifyNoSelectionCallbacks[pluginApiIdentifiers].push(contentFunction);
}

let _modifyCollectionHeaderCallbacks = {};
function modifyCollectionHeader(pluginApiIdentifiers, contentFunction) {
  if (isNone(_modifyCollectionHeaderCallbacks[pluginApiIdentifiers])) {
    _modifyCollectionHeaderCallbacks[pluginApiIdentifiers] = [];
  }

  _modifyCollectionHeaderCallbacks[pluginApiIdentifiers].push(contentFunction);
}

let _onSelectCallbacks = {};
function onSelect(pluginApiIdentifiers, mutationFunction) {
  if (isNone(_onSelectCallbacks[pluginApiIdentifiers])) {
    _onSelectCallbacks[pluginApiIdentifiers] = [];
  }

  _onSelectCallbacks[pluginApiIdentifiers].push(mutationFunction);
}

let _onOpenCallbacks = {};
function onOpen(pluginApiIdentifiers, mutationFunction) {
  if (isNone(_onOpenCallbacks[pluginApiIdentifiers])) {
    _onOpenCallbacks[pluginApiIdentifiers] = [];
  }

  _onOpenCallbacks[pluginApiIdentifiers].push(mutationFunction);
}

let _onCloseCallbacks = {};
function onClose(pluginApiIdentifiers, mutationFunction) {
  if (isNone(_onCloseCallbacks[pluginApiIdentifiers])) {
    _onCloseCallbacks[pluginApiIdentifiers] = [];
  }

  _onCloseCallbacks[pluginApiIdentifiers].push(mutationFunction);
}

let _onInputCallbacks = {};
function onInput(pluginApiIdentifiers, mutationFunction) {
  if (isNone(_onInputCallbacks[pluginApiIdentifiers])) {
    _onInputCallbacks[pluginApiIdentifiers] = [];
  }

  _onInputCallbacks[pluginApiIdentifiers].push(mutationFunction);
}

export function applyContentPluginApiCallbacks(
  identifiers,
  content,
  selectKit
) {
  identifiers.forEach(key => {
    (_prependContentCallbacks[key] || []).forEach(c => {
      content = Ember.makeArray(c(selectKit, content)).concat(content);
    });
    (_appendContentCallbacks[key] || []).forEach(c => {
      content = content.concat(Ember.makeArray(c(selectKit, content)));
    });
    const filterCallbacks = _filterContentCallbacks[key] || [];
    if (filterCallbacks.length) {
      content = content.filter(c => {
        let kept = true;
        filterCallbacks.forEach(cb => {
          kept = cb(selectKit, c);
        });
        return kept;
      });
    }
    (_modifyContentCallbacks[key] || []).forEach(c => {
      content = c(selectKit, content);
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
export function applyModifyNoSelectionPluginApiCallbacks(
  identifiers,
  content,
  context
) {
  identifiers.forEach(key => {
    (_modifyNoSelectionCallbacks[key] || []).forEach(c => {
      content = c(context, content);
    });
  });

  return content;
}

export function applyCollectionHeaderCallbacks(
  identifiers,
  content,
  selectKit
) {
  identifiers.forEach(key => {
    (_modifyCollectionHeaderCallbacks[key] || []).forEach(c => {
      content = c(selectKit, content);
    });
  });

  return content;
}

export function applyOnSelectPluginApiCallbacks(identifiers, val, selectKit) {
  identifiers.forEach(key => {
    (_onSelectCallbacks[key] || []).forEach(c => c(selectKit, val));
  });
}

export function applyOnOpenPluginApiCallbacks(identifiers, selectKit, event) {
  let keepBubbling = true;
  identifiers.forEach(key => {
    (_onOpenCallbacks[key] || []).forEach(
      c => (keepBubbling = c(selectKit, event))
    );
  });
  return keepBubbling;
}

export function applyOnClosePluginApiCallbacks(identifiers, selectKit, event) {
  let keepBubbling = true;
  identifiers.forEach(key => {
    (_onCloseCallbacks[key] || []).forEach(
      c => (keepBubbling = c(selectKit, event))
    );
  });
  return keepBubbling;
}

export function applyOnInputPluginApiCallbacks(identifiers, event, selectKit) {
  let keepBubbling = true;
  identifiers.forEach(key => {
    (_onInputCallbacks[key] || []).forEach(
      c => (keepBubbling = c(selectKit, event))
    );
  });
  return keepBubbling;
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
    filterContent: filterFunction => {
      filterContent(pluginApiIdentifiers, filterFunction);
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
    modifySelection: callback => {
      modifyHeaderComputedContent(pluginApiIdentifiers, callback);
      return modifySelectKit(pluginApiIdentifiers);
    },
    modifyNoSelection: callback => {
      modifyNoSelection(pluginApiIdentifiers, callback);
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
    onClose: callback => {
      onClose(pluginApiIdentifiers, callback);
      return modifySelectKit(pluginApiIdentifiers);
    },
    onOpen: callback => {
      onOpen(pluginApiIdentifiers, callback);
      return modifySelectKit(pluginApiIdentifiers);
    },
    onInput: callback => {
      onInput(pluginApiIdentifiers, callback);
      return modifySelectKit(pluginApiIdentifiers);
    }
  };
}

export function clearCallbacks() {
  _appendContentCallbacks = {};
  _prependContentCallbacks = {};
  _filterContentCallbacks = {};
  _modifyNoSelectionCallbacks = {};
  _modifyContentCallbacks = {};
  _modifyHeaderComputedContentCallbacks = {};
  _modifyCollectionHeaderCallbacks = {};
  _onSelectCallbacks = {};
  _onCloseCallbacks = {};
  _onOpenCallbacks = {};
  _onInputCallbacks = {};
}

const EMPTY_ARRAY = Object.freeze([]);
export default Mixin.create({
  concatenatedProperties: ["pluginApiIdentifiers"],
  pluginApiIdentifiers: EMPTY_ARRAY
});
