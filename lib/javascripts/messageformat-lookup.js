(function () {
  I18n.messageFormat = function (key, options) {
    var message = I18n._mf_messages.hasMessage(
      key,
      I18n._mf_messages.locale,
      I18n._mf_messages.defaultLocale
    );
    if (message) {
      try {
        return I18n._mf_messages.get(key, options);
      } catch (err) {
        return err.message;
      }
    } else {
      return "Missing Key: " + key;
    }
  };
})();
