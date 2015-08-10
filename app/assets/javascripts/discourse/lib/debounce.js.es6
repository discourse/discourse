/**
  Debounce a Javascript function. This means if it's called many times in a time limit it
  should only be executed once (at the end of the limit counted from the last call made).
  Original function will be called with the context and arguments from the last call made.
**/
export default function(func, wait) {
  let self, args;
  const later = function() {
    func.apply(self, args);
  };

  return function() {
    self = this;
    args = arguments;

    Ember.run.debounce(null, later, wait);
  };
}
