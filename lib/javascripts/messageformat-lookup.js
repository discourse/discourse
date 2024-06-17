(function () {
  I18n.messageFormat = function (key, options) {
    console.log("in messageFormat()");
    var fn = I18n._compiledMFs[key];
    if (fn) {
      try {
        return fn(options);
      } catch (err) {
        return err.message;
      }
    } else {
      return "Missing Key: " + key;
    }
  };
  I18n.plop = function () {
    return "PLOP";
  };
})();
