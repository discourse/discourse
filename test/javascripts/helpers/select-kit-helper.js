function checkSelectKitIsNotExpanded(selector) {
  if (find(selector).hasClass('is-expanded')) {
    throw 'You expected select-kit to be collapsed but it is expanded.';
  }
}

function checkSelectKitIsNotCollapsed(selector) {
  if (!find(selector).hasClass('is-expanded')) {
    throw 'You expected select-kit to be expanded but it is collapsed.';
  }
}

Ember.Test.registerAsyncHelper('expandSelectKit', function(app, selector) {
  selector = selector || '.select-kit';

  checkSelectKitIsNotExpanded(selector);

  click(selector + ' .select-kit-header');
});

Ember.Test.registerAsyncHelper('collapseSelectKit', function(app, selector) {
  selector = selector || '.select-kit';

  checkSelectKitIsNotCollapsed(selector);

  click(selector + ' .select-kit-header');
});

Ember.Test.registerAsyncHelper('selectKitSelectRow', function(app, rowValue, options) {
  options = options || {};
  options.selector = options.selector || '.select-kit';

  checkSelectKitIsNotCollapsed(options.selector);

  click(options.selector + " .select-kit-row[data-value='" + rowValue + "']");
});

Ember.Test.registerAsyncHelper('selectKitSelectNoneRow', function(app, options) {
  options = options || {};
  options.selector = options.selector || '.select-kit';

  checkSelectKitIsNotCollapsed(options.selector);

  click(options.selector + " .select-kit-row.none");
});

Ember.Test.registerAsyncHelper('selectKitFillInFilter', function(app, filter, options) {
  options = options || {};
  options.selector = options.selector || '.select-kit';

  checkSelectKitIsNotCollapsed(options.selector);

  var filterQuerySelector = options.selector + ' .filter-input';
  fillIn(filterQuerySelector, filter);

});

function selectKit(selector) { // eslint-disable-line no-unused-vars
  selector = selector || '.select-kit';

  function rowHelper(row) {
    return {
      name: function() { return row.attr('data-name'); },
      icon: function() { return row.find('.d-icon'); },
      title: function() { return row.attr('title'); },
      value: function() { return row.attr('data-value'); },
      el: row
    };
  }

  function headerHelper(header) {
    return {
      name: function() {
        return header.attr('data-name');
      },
      icon: function() { return header.find('.icon'); },
      title: function() { return header.attr('title'); },
      el: header
    };
  }

  function filterHelper(filter) {
    return {
      icon: function() { return filter.find('.d-icon'); },
      exists: function() { return exists(filter); },
      el: filter
    };
  }

  function keyboardHelper() {
    function createEvent(target, keyCode, options) {
      target = target || ".filter-input";
      selector = find(selector).find(target);
      options = options || {};

      andThen(function() {
        var type = options.type || 'keydown';
        var event = jQuery.Event(type);
        event.keyCode = keyCode;
        if (options && options.metaKey === true) { event.metaKey = true; }
        find(selector).trigger(event);
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
  }

  return {
    keyboard: keyboardHelper(),

    isExpanded: find(selector).hasClass('is-expanded'),

    isHidden: find(selector).hasClass('is-hidden'),

    header: headerHelper(find(selector).find('.select-kit-header')),

    filter: filterHelper(find(selector).find('.select-kit-filter')),

    rows: find(selector).find('.select-kit-row'),

    rowByValue: function(value) {
      return rowHelper(find(selector).find('.select-kit-row[data-value="' + value + '"]'));
    },

    rowByName: function(name) {
      return rowHelper(find(selector).find('.select-kit-row[data-name="' + name + '"]'));
    },

    rowByIndex: function(index) {
      return rowHelper(find(selector).find('.select-kit-row:eq(' + index + ')'));
    },

    el: find(selector),

    noneRow: rowHelper(find(selector).find('.select-kit-row.none')),

    selectedRow: rowHelper(find(selector).find('.select-kit-row.is-selected')),

    highlightedRow: rowHelper(find(selector).find('.select-kit-row.is-highlighted'))
  };
}
