var filters = {};

// use filter API to register a callback from a plugin
const filter = function(name, fn) {
  var current = filters[name] = filters[name] || [];
  current.push(fn);
};

const runFilters = function(name, val) {
  const current = filters[name];
  if (current) {

    var args = Array.prototype.slice.call(arguments, 1);

    for(var i = 0; i < current.length; i++) {
      val = current[i].apply(this, args);
    }
  }

  return val;
};

export { runFilters };
export default filter;
