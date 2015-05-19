function extractError(error) {
  if (error instanceof Error) {
    Ember.Logger.error(error.stack);
  }

  if (typeof error === "string") {
    Ember.Logger.error(error);
  }

  if (error.jqXHR) {
    error = error.jqXHR;
  }

  let parsedError, parsedJSON;

  if (error.responseJSON) {
    parsedJSON = error.responseJSON;
  }

  if (!parsedJSON && error.responseText) {
    try {
      parsedJSON = $.parseJSON(error.responseText);
    } catch(ex) {
      // in case the JSON doesn't parse
      Ember.Logger.error(ex.stack);
    }
  }

  if (parsedJSON) {
    if (parsedJSON.errors && parsedJSON.errors.length > 0) {
      parsedError = parsedJSON.errors[0];
    } else if (parsedJSON.error) {
      parsedError = parsedJSON.error;
    } else if (parsedJSON.failed) {
      parsedError = parsedJSON.message;
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

export function popupAjaxError(error) {
  bootbox.alert(extractError(error));
}
