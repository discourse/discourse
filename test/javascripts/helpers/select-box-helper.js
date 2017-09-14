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
  selectBoxSelector = selectBoxSelector || '.select-box';

  checkSelectBoxIsNotExpanded(selectBoxSelector);

  click(selectBoxSelector + ' .select-box-header');
});

Ember.Test.registerAsyncHelper('collapseSelectBox', function(app, selectBoxSelector) {
  selectBoxSelector = selectBoxSelector || '.select-box';

  checkSelectBoxIsNotCollapsed(selectBoxSelector);

  click(selectBoxSelector + ' .select-box-header');
});

Ember.Test.registerAsyncHelper('selectBoxSelectRow', function(app, rowId, options) {
  options = options || {};
  options.selector = options.selector || '.select-box';

  checkSelectBoxIsNotCollapsed(options.selector);

  click(options.selector + " .select-box-row[data-id='" + rowId + "']");
});

Ember.Test.registerAsyncHelper('selectBoxFillInFilter', function(app, filter, options) {
  options = options || {};
  options.selector = options.selector || '.select-box';

  checkSelectBoxIsNotCollapsed(options.selector);

  var filterQuerySelector = options.selector + ' .filter-query';
  fillIn(filterQuerySelector, filter);
  triggerEvent(filterQuerySelector, 'keyup');
});

function selectBox(selector) { // eslint-disable-line no-unused-vars
  selector = selector || '.select-box';

  function rowHelper(row) {
    return {
      text: function() { return row.find('.text').text().trim(); },
      icon: function() { return row.find('.d-icon'); },
      title: function() { return row.attr('title'); },
      el: function() { return row; }
    };
  }

  function headerHelper(header) {
    return {
      text: function() { return header.find('.current-selection').text().trim(); },
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
      if (typeof target !== 'undefined') {
        selector = find(selector).find(target);
      }

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

    header: headerHelper(find(selector).find('.select-box-header')),

    filter: filterHelper(find(selector).find('.select-box-filter')),

    rows: find(selector).find('.select-box-row'),

    row: function(id) {
      return rowHelper(find(selector).find('.select-box-row[data-id="' + id + '"]'));
    },

    selectedRow: rowHelper(find(selector).find('.select-box-row.is-selected')),

    highlightedRow: rowHelper(find(selector).find('.select-box-row.is-highlighted'))
  };
}
