/* exported exists, count, present, blank, containsInstance, not, visible, invisible */

function exists(selector) {
  return !!count(selector);
}

function count(selector) {
  return find(selector).length;
}

function containsInstance(collection, klass, text) {
  ok(klass.detectInstance(_.first(collection)), text);
}

function not(state, message) {
  ok(!state, message);
}

function visible(selector) {
  return find(selector + ":visible").length > 0;
}

Ember.Test.registerAsyncHelper('selectDropdown', function(app, selector, itemId) {
  var $select2 = find(selector);
  $select2.select2('val', itemId.toString());
  $select2.trigger("change");
});

function invisible(selector) {
  var $items = find(selector + ":visible");
  return $items.length === 0 ||
         $items.css("opacity") === "0" ||
         $items.css("visibility") === "hidden";
}
