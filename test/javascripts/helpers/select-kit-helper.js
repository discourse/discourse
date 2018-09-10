function checkSelectKitIsNotExpanded(selector) {
  if (find(selector).hasClass("is-expanded")) {
    throw new Error(
      "You expected select-kit to be collapsed but it is expanded."
    );
  }
}

function checkSelectKitIsNotCollapsed(selector) {
  if (!find(selector).hasClass("is-expanded")) {
    throw new Error(
      "You expected select-kit to be expanded but it is collapsed."
    );
  }
}

Ember.Test.registerAsyncHelper("expandSelectKit", function(app, selector) {
  checkSelectKitIsNotExpanded(selector);
  click(selector + " .select-kit-header");
});

Ember.Test.registerAsyncHelper("collapseSelectKit", function(app, selector) {
  checkSelectKitIsNotCollapsed(selector);
  click(selector + " .select-kit-header");
});

Ember.Test.registerAsyncHelper("selectKitFillInFilter", function(
  app,
  filter,
  selector
) {
  checkSelectKitIsNotCollapsed(selector);
  fillIn(selector + " .filter-input", filter);
});

Ember.Test.registerAsyncHelper("selectKitSelectRowByValue", function(
  app,
  value,
  selector
) {
  checkSelectKitIsNotCollapsed(selector);
  click(selector + " .select-kit-row[data-value='" + value + "']");
});

Ember.Test.registerAsyncHelper("selectKitSelectRowByName", function(
  app,
  name,
  selector
) {
  checkSelectKitIsNotCollapsed(selector);
  click(selector + " .select-kit-row[data-name='" + name + "']");
});

Ember.Test.registerAsyncHelper("selectKitSelectNoneRow", function(
  app,
  selector
) {
  checkSelectKitIsNotCollapsed(selector);
  click(selector + " .select-kit-row.none");
});

Ember.Test.registerAsyncHelper("selectKitSelectRowByIndex", function(
  app,
  index,
  selector
) {
  checkSelectKitIsNotCollapsed(selector);
  click(find(selector + " .select-kit-row").eq(index));
});

Ember.Test.registerAsyncHelper("keyboardHelper", function(
  app,
  value,
  target,
  selector
) {
  function createEvent(element, keyCode, options) {
    element = element || ".filter-input";
    selector = find(selector).find(element);
    options = options || {};

    var type = options.type || "keydown";
    var event = jQuery.Event(type);
    event.keyCode = keyCode;
    if (options && options.metaKey) {
      event.metaKey = true;
    }

    andThen(() => {
      find(selector).trigger(event);
    });
  }

  switch (value) {
    case "enter":
      return createEvent(target, 13);
    case "backspace":
      return createEvent(target, 8);
    case "selectAll":
      return createEvent(target, 65, { metaKey: true });
    case "escape":
      return createEvent(target, 27);
    case "down":
      return createEvent(target, 40);
    case "up":
      return createEvent(target, 38);
    case "tab":
      return createEvent(target, 9);
  }
});

// eslint-disable-next-line no-unused-vars
function selectKit(selector) {
  selector = selector || ".select-kit";

  function rowHelper(row) {
    return {
      name: function() {
        return row.attr("data-name");
      },
      icon: function() {
        return row.find(".d-icon");
      },
      title: function() {
        return row.attr("title");
      },
      value: function() {
        return row.attr("data-value");
      },
      exists: function() {
        return exists(row);
      },
      el: function() {
        return row;
      }
    };
  }

  function headerHelper(header) {
    return {
      value: function() {
        return header.attr("data-value");
      },
      name: function() {
        return header.attr("data-name");
      },
      label: function() {
        return header.text().trim();
      },
      icon: function() {
        return header.find(".icon");
      },
      title: function() {
        return header.attr("title");
      },
      el: function() {
        return header;
      }
    };
  }

  function filterHelper(filter) {
    return {
      icon: function() {
        return filter.find(".d-icon");
      },
      exists: function() {
        return exists(filter);
      },
      el: function() {
        return filter;
      }
    };
  }

  return {
    expand: function() {
      return expandSelectKit(selector);
    },

    collapse: function() {
      return collapseSelectKit(selector);
    },

    selectRowByIndex: function(index) {
      selectKitSelectRowByIndex(index, selector);
      return selectKit(selector);
    },

    selectRowByValue: function(value) {
      return selectKitSelectRowByValue(value, selector);
    },

    // Remove when stable is updated to Discourse 2.1
    selectRowByValueAwait: function(value) {
      return selectKitSelectRowByValue(value, selector);
    },

    selectRowByName: function(name) {
      selectKitSelectRowByValue(name, selector);
      return selectKit(selector);
    },

    selectNoneRow: function() {
      return selectKitSelectNoneRow(selector);
    },

    fillInFilter: function(filter) {
      return selectKitFillInFilter(filter, selector);
    },

    keyboard: function(value, target) {
      return keyboardHelper(value, target, selector);
    },

    isExpanded: function() {
      return find(selector).hasClass("is-expanded");
    },

    isFocused: function() {
      return find(selector).hasClass("is-focused");
    },

    isHidden: function() {
      return find(selector).hasClass("is-hidden");
    },

    header: function() {
      return headerHelper(find(selector).find(".select-kit-header"));
    },

    filter: function() {
      return filterHelper(find(selector).find(".select-kit-filter"));
    },

    rows: function() {
      return find(selector).find(".select-kit-row");
    },

    rowByValue: function(value) {
      return rowHelper(
        find(selector).find('.select-kit-row[data-value="' + value + '"]')
      );
    },

    rowByName: function(name) {
      return rowHelper(
        find(selector).find('.select-kit-row[data-name="' + name + '"]')
      );
    },

    rowByIndex: function(index) {
      return rowHelper(
        find(selector).find(".select-kit-row:eq(" + index + ")")
      );
    },

    el: function() {
      return find(selector);
    },

    noneRow: function() {
      return rowHelper(find(selector).find(".select-kit-row.none"));
    },

    validationMessage: function() {
      var validationMessage = find(selector).find(".validation-message");

      if (validationMessage.length) {
        return validationMessage.html().trim();
      } else {
        return null;
      }
    },

    selectedRow: function() {
      return rowHelper(find(selector).find(".select-kit-row.is-selected"));
    },

    highlightedRow: function() {
      return rowHelper(find(selector).find(".select-kit-row.is-highlighted"));
    },

    exists: function() {
      return exists(selector);
    }
  };
}
