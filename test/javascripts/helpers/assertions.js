/* exported exists, count, present, blank, containsInstance, not, visible, invisible */

function exists(selector) {
  return count(selector) > 0;
}

function count(selector) {
  return find(selector).length;
}

function visible(selector) {
  return find(selector + ":visible").length > 0;
}

Ember.Test.registerAsyncHelper('selectDropdown', function(app, selector, itemId) {
  var $select2 = find(selector);
  $select2.select2('val', itemId.toString());
  $select2.trigger("change");
});

Ember.Test.registerAsyncHelper('selectBox', function(app, selector, title) {
  click(`${selector} .select-box-header`);
  click(`${selector} .select-box-row[title="${title}"]`);
});

function invisible(selector) {
  var $items = find(selector + ":visible");
  return $items.length === 0 ||
         $items.css("opacity") === "0" ||
         $items.css("visibility") === "hidden";
}
