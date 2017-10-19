function checkSelectBoxIsNotExpanded(selectBoxSelector) {
  if (find(selectBoxSelector).hasClass('is-expanded')) {
    throw 'You expected select-box to be collapsed but it is expanded.';
  }
}

function checkSelectBoxIsNotCollapsed(selectBoxSelector) {
  if (!find(selectBoxSelector).hasClass('is-expanded')) {
    throw 'You expected select-box to be expanded but it is collapsed.';
  }
}

Ember.Test.registerAsyncHelper('expandSelectBox', function(app, selectBoxSelector) {
  selectBoxSelector = selectBoxSelector || '.select-box-kit';

  checkSelectBoxIsNotExpanded(selectBoxSelector);

  click(selectBoxSelector + ' .select-box-kit-header');
});

Ember.Test.registerAsyncHelper('collapseSelectBox', function(app, selectBoxSelector) {
  selectBoxSelector = selectBoxSelector || '.select-box-kit';

  checkSelectBoxIsNotCollapsed(selectBoxSelector);

  click(selectBoxSelector + ' .select-box-kit-header');
});

Ember.Test.registerAsyncHelper('selectBoxSelectRow', function(app, rowValue, options) {
  options = options || {};
  options.selector = options.selector || '.select-box-kit';

  checkSelectBoxIsNotCollapsed(options.selector);

  click(options.selector + " .select-box-kit-row[data-value='" + rowValue + "']");
});

Ember.Test.registerAsyncHelper('selectBoxSelectNoneRow', function(app, options) {
  options = options || {};
  options.selector = options.selector || '.select-box-kit';

  checkSelectBoxIsNotCollapsed(options.selector);

  click(options.selector + " .select-box-kit-row.none");
});

Ember.Test.registerAsyncHelper('selectBoxFillInFilter', function(app, filter, options) {
  options = options || {};
  options.selector = options.selector || '.select-box-kit';

  checkSelectBoxIsNotCollapsed(options.selector);

  var filterQuerySelector = options.selector + ' .select-box-kit-filter-input';
  fillIn(filterQuerySelector, filter);
  triggerEvent(filterQuerySelector, 'keyup');
});

function selectBox(selector) { // eslint-disable-line no-unused-vars
  selector = selector || '.select-box-kit';

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
    function createEvent(target, keyCode) {
      target = target || ".select-box-kit-filter-input";
      selector = find(selector).find(target);

      andThen(function() {
        var event = jQuery.Event('keydown');
        event.keyCode = keyCode;
        find(selector).trigger(event);
      });
    }

    return {
      down: function(target) { createEvent(target, 40); },
      up: function(target) { createEvent(target, 38); },
      escape: function(target) { createEvent(target, 27); },
      enter: function(target) { createEvent(target, 13); },
      tab: function(target) { createEvent(target, 9); }
    };
  }

  return {
    keyboard: keyboardHelper(),

    isExpanded: find(selector).hasClass('is-expanded'),

    isHidden: find(selector).hasClass('is-hidden'),

    header: headerHelper(find(selector).find('.select-box-kit-header')),

    filter: filterHelper(find(selector).find('.select-box-kit-filter')),

    rows: find(selector).find('.select-box-kit-row'),

    rowByValue: function(value) {
      return rowHelper(find(selector).find('.select-box-kit-row[data-value="' + value + '"]'));
    },

    rowByName: function(name) {
      return rowHelper(find(selector).find('.select-box-kit-row[data-name="' + name + '"]'));
    },

    rowByIndex: function(index) {
      return rowHelper(find(selector).find('.select-box-kit-row:eq(' + index + ')'));
    },

    el: find(selector),

    noneRow: rowHelper(find(selector).find('.select-box-kit-row.none')),

    selectedRow: rowHelper(find(selector).find('.select-box-kit-row.is-selected')),

    highlightedRow: rowHelper(find(selector).find('.select-box-kit-row.is-highlighted'))
  };
}
