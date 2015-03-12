/* exported exists, count, present, blank, containsInstance, not, visible */

function exists(selector) {
  return !!count(selector);
}

function count(selector) {
  return find(selector).length;
}

function present(obj, text) {
  ok(!Ember.isEmpty(obj), text);
}

function blank(obj, text) {
  ok(Ember.isEmpty(obj), text);
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

function invisible(selector) {
  var $items = find(selector + ":visible");
  return $items.length === 0 ||
         $items.css("opacity") === "0" ||
         $items.css("visibility") === "hidden";
}
