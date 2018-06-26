function checkSelectKitIsNotExpanded(selector) {
  if (find(selector).hasClass('is-expanded')) {
    throw new Error('You expected select-kit to be collapsed but it is expanded.');
  }
}

function checkSelectKitIsNotCollapsed(selector) {
  if (!find(selector).hasClass('is-expanded')) {
    throw new Error('You expected select-kit to be expanded but it is collapsed.');
  }
}

Ember.Test.registerAsyncHelper('expandSelectKit', function(app, selector) {
  checkSelectKitIsNotExpanded(selector);
  click(selector + ' .select-kit-header');
});

Ember.Test.registerAsyncHelper('collapseSelectKit', function(app, selector) {
  checkSelectKitIsNotCollapsed(selector);
  click(selector + ' .select-kit-header');
});

Ember.Test.registerAsyncHelper('selectKitFillInFilter', function(app, filter, selector) {
  checkSelectKitIsNotCollapsed(selector);
  fillIn(selector + ' .filter-input', filter);
});

Ember.Test.registerAsyncHelper('selectKitSelectRowByValue', function(app, value, selector) {
  checkSelectKitIsNotCollapsed(selector);
  click(selector + " .select-kit-row[data-value='" + value + "']");
});

Ember.Test.registerAsyncHelper('selectKitSelectRowByName', function(app, name, selector) {
  checkSelectKitIsNotCollapsed(selector);
  click(selector + " .select-kit-row[data-name='" + name + "']");
});

Ember.Test.registerAsyncHelper('selectKitSelectNoneRow', function(app, selector) {
  checkSelectKitIsNotCollapsed(selector);
  click(selector + " .select-kit-row.none");
});

Ember.Test.registerAsyncHelper('selectKitSelectRowByIndex', function(app, index, selector) {
  checkSelectKitIsNotCollapsed(selector);
  click(find(selector + " .select-kit-row").eq(index));
});

function selectKit(selector) { // eslint-disable-line no-unused-vars
  selector = selector || ".select-kit";

  function rowHelper(row) {
    return {
      name: function() { return row.attr('data-name'); },
      icon: function() { return row.find('.d-icon'); },
      title: function() { return row.attr('title'); },
      value: function() { return row.attr('data-value'); },
      exists: function() { return exists(row); },
      el: function() { return row; }
    };
  }

  function headerHelper(header) {
    return {
      value: function() { return header.attr('data-value'); },
      name: function() { return header.attr('data-name'); },
      label: function() { return header.text().trim(); },
      icon: function() { return header.find('.icon'); },
      title: function() { return header.attr('title'); },
      el: function() { return header; }
    };
  }

  function filterHelper(filter) {
    return {
      icon: function() { return filter.find('.d-icon'); },
      exists: function() { return exists(filter); },
      el: function() { return filter; }
    };
  }

  function keyboardHelper(eventSelector) {
    function createEvent(target, keyCode, options) {
      target = target || ".filter-input";
      eventSelector = find(eventSelector).find(target);
      options = options || {};

      andThen(function() {
        var type = options.type || 'keydown';
        var event = jQuery.Event(type);
        event.keyCode = keyCode;
        if (options && options.metaKey) { event.metaKey = true; }
        find(eventSelector).trigger(event);
      });
    }

    return {
      down: function(target) { createEvent(target, 40); },
      up: function(target) { createEvent(target, 38); },
      escape: function(target) { createEvent(target, 27); },
      enter: function(target) { createEvent(target, 13); },
      tab: function(target) { createEvent(target, 9); },
      backspace: function(target) { createEvent(target, 8); },
      selectAll: function(target) { createEvent(target, 65, {metaKey: true}); },
    };
  };

  return {
    expandAwait: function() {
      return expandSelectKit(selector);
    },

    expand: function() {
      expandSelectKit(selector);
      return selectKit(selector);
    },

    collapse: function() {
      collapseSelectKit(selector);
      return selectKit(selector);
    },

    selectRowByIndex: function(index) {
      selectKitSelectRowByIndex(index, selector);
      return selectKit(selector);
    },

    selectRowByValueAwait: function(value) {
      return selectKitSelectRowByValue(value, selector);
    },

    selectRowByValue: function(value) {
      selectKitSelectRowByValue(value, selector);
      return selectKit(selector);
    },

    selectRowByName: function(name) {
      selectKitSelectRowByValue(name, selector);
      return selectKit(selector);
    },

    selectNoneRow: function() {
      selectKitSelectNoneRow(selector);
      return selectKit(selector);
    },

    fillInFilter: function(filter) {
      selectKitFillInFilter(filter, selector);
      return selectKit(selector);
    },

    keyboard: function() { return keyboardHelper(selector); },

    isExpanded: function() {
      return find(selector).hasClass('is-expanded');
    },

    isFocused: function() {
      return find(selector).hasClass('is-focused');
    },

    isHidden: function() {
      return find(selector).hasClass('is-hidden');
    },

    header: function() {
      return headerHelper(find(selector).find('.select-kit-header'));
    },

    filter: function() {
      return filterHelper(find(selector).find('.select-kit-filter'));
    },

    rows: function() {
      return find(selector).find('.select-kit-row');
    },

    rowByValue: function(value) {
      return rowHelper(find(selector).find('.select-kit-row[data-value="' + value + '"]'));
    },

    rowByName: function(name) {
      return rowHelper(find(selector).find('.select-kit-row[data-name="' + name + '"]'));
    },

    rowByIndex: function(index) {
      return rowHelper(find(selector).find('.select-kit-row:eq(' + index + ')'));
    },

    el: function() { return find(selector); },

    noneRow: function() {
      return rowHelper(find(selector).find('.select-kit-row.none'));
    },

    validationMessage: function() {
      var validationMessage = find(selector).find('.validation-message');

      if (validationMessage.length) {
        return validationMessage.html().trim();
      } else {
        return null;
      }
    },

    selectedRow: function() {
      return rowHelper(find(selector).find('.select-kit-row.is-selected'));
    },

    highlightedRow: function() {
      return rowHelper(find(selector).find('.select-kit-row.is-highlighted'));
    },

    exists: function() { return exists(selector); }
  };
}
