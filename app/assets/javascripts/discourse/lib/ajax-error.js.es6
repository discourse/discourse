function extractError(error) {
  if (error instanceof Error) {
    Ember.Logger.error(error.stack);
  }

  if (typeof error === "string") {
    Ember.Logger.error(error);
  }

  let parsedError;
  if (error.responseText) {
    try {
      const parsedJSON = $.parseJSON(error.responseText);
      if (parsedJSON.errors) {
        parsedError = parsedJSON.errors[0];
      } else if (parsedJSON.failed) {
        parsedError = parsedJSON.message;
      }
    } catch(ex) {
      // in case the JSON doesn't parse
      Ember.Logger.error(ex.stack);
    }
  }
  return parsedError || I18n.t('generic_error');
}

export function throwAjaxError(undoCallback) {
  return function(error) {
    // If we provided an `undo` callback
    if (undoCallback) { undoCallback(error); }

    throw extractError(error);
  };
}

export function popupAjaxError(err) {
  bootbox.alert(extractError(err));
}
