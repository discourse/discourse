import { htmlSafe } from "@ember/template";
import $ from "jquery";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { i18n } from "discourse-i18n";

function extractErrorInfo(error, defaultMessage) {
  if (error instanceof Error) {
    // eslint-disable-next-line no-console
    console.error(error.stack);
  }

  if (typeof error === "string") {
    // eslint-disable-next-line no-console
    console.error(error);
  }

  if (error.jqXHR) {
    error = error.jqXHR;
  }

  let html = false,
    parsedError,
    parsedJSON;

  if (error.responseJSON) {
    parsedJSON = error.responseJSON;
  }

  if (!parsedJSON && error.responseText) {
    try {
      parsedJSON = $.parseJSON(error.responseText);
    } catch (ex) {
      // in case the JSON doesn't parse
      // eslint-disable-next-line no-console
      console.error(ex.stack);
    }
  }

  if (parsedJSON) {
    if (parsedJSON.html_message) {
      html = true;
    }

    if (parsedJSON.errors?.length > 1) {
      parsedError = i18n("multiple_errors", {
        errors: parsedJSON.errors.map((e, i) => `${i + 1}) ${e}`).join(" "),
      });
    } else if (parsedJSON.errors?.length > 0) {
      parsedError = i18n("generic_error_with_reason", {
        error: parsedJSON.errors[0],
      });
    } else if (parsedJSON.error) {
      parsedError = parsedJSON.error;
    } else if (parsedJSON.message) {
      parsedError = parsedJSON.message;
    } else if (parsedJSON.failed) {
      parsedError = parsedJSON.failed;
    }
  }

  if (!parsedError) {
    if (error.status && error.status >= 400) {
      parsedError = error.status + " " + error.statusText;
    }
  }

  return {
    html,
    message: parsedError || defaultMessage || i18n("generic_error"),
  };
}

export function extractError(error, defaultMessage) {
  return extractErrorInfo(error, defaultMessage).message;
}

export function throwAjaxError(undoCallback, defaultMessage) {
  return function (error) {
    // If we provided an `undo` callback
    if (undoCallback) {
      undoCallback(error);
    }
    throw extractError(error, defaultMessage);
  };
}

export function flashAjaxError(modal, defaultMessage) {
  return (error) => {
    modal.flash(extractError(error, defaultMessage), "error");
  };
}

export function popupAjaxError(error) {
  const dialog = getOwnerWithFallback(this).lookup("service:dialog");
  const errorInfo = extractErrorInfo(error);

  if (errorInfo.html) {
    dialog.alert({ message: htmlSafe(errorInfo.message) });
  } else {
    dialog.alert(errorInfo.message);
  }
}
