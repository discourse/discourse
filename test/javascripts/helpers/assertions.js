// Test helpers
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