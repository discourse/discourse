(function() {
  if (typeof I18n !== "undefined") {
    if ("w" in String.prototype) {
      String.prototype.i18n = function(options) {
        return I18n.t(String(this), options);
      };
    }
  }
})();
