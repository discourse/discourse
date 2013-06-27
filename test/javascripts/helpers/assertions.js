// Test helpers
var resolvingPromise = Ember.Deferred.promise(function (p) {
  p.resolve();
})

function exists(selector) {
  return !!count(selector);
}

function count(selector) {
  return find(selector).length;
}

function objBlank(obj) {
  if (obj === undefined) return true;

  switch (typeof obj) {
  case "string":
    return obj.trim().length === 0;
  case "object":
    return $.isEmptyObject(obj);
  }
  return false;
}

function present(obj, text) {
  equal(objBlank(obj), false, text);
}

function blank(obj, text) {
  equal(objBlank(obj), true, text);
}