(function() {
  var preloadedDataElement = document.getElementById("data-preloaded");

  if (preloadedDataElement) {
    var ps = require("preload-store").default;
    var preloaded = JSON.parse(preloadedDataElement.dataset.preloaded);

    Object.keys(preloaded).forEach(function(key) {
      ps.store(key, JSON.parse(preloaded[key]));
    });
  }
})();
