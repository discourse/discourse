import { trustHTML } from "@ember/template";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { i18n } from "discourse-i18n";

export const TOO_MANY_REQUESTS = 429;
const DEFAULT_RATE_LIMIT_WAIT_SECONDS = 15;
export const MAX_RATE_LIMIT_RETRY_SECONDS = 60;

export function extractErrorInfo(
  error,
  defaultMessage,
  opts = { skipConsoleError: false }
) {
  const skipConsoleError = opts.skipConsoleError ?? false;

  if (error instanceof Error) {
    if (!skipConsoleError) {
      // eslint-disable-next-line no-console
      console.error(error.stack);
    }
  }

  if (typeof error === "string") {
    if (!skipConsoleError) {
      // eslint-disable-next-line no-console
      console.error(error);
    }
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

  const contentType = error.getResponseHeader?.("Content-Type");
  const isJSON = !contentType || contentType.includes("json");

  if (!parsedJSON && isJSON && error.responseText) {
    try {
      parsedJSON = JSON.parse(error.responseText);
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
    } else if (parsedJSON.error_key) {
      parsedError = i18n(parsedJSON.error_key);
    }
  }

  if (!parsedError && isRateLimitError(error)) {
    parsedError = i18n("too_many_requests", {
      count: rateLimitWaitSeconds(error),
    });
  }

  if (!parsedError) {
    if (error.status && error.status >= 400) {
      parsedError = error.status + " " + error.statusText;
    }
  }

  return {
    html,
    message: parsedError || defaultMessage || i18n("generic_error"),
    errorKey: parsedJSON?.error_key ?? null,
    status: error.status ?? null,
  };
}

export function extractError(error, defaultMessage) {
  return extractErrorInfo(error, defaultMessage).message;
}

function responseFor(error) {
  return error.jqXHR ?? error.source ?? error;
}

export function isReadOnlyError(error) {
  const xhr = responseFor(error);
  return xhr.status === 503 && xhr.responseJSON?.error_type === "read_only";
}

export function isRateLimitError(error) {
  return responseFor(error).status === TOO_MANY_REQUESTS;
}

export function rateLimitWaitSeconds(error) {
  const xhr = responseFor(error);

  const retryAfter = parseInt(xhr.getResponseHeader?.("Retry-After"), 10);
  if (retryAfter > 0) {
    return retryAfter;
  }

  const waitSeconds = xhr.responseJSON?.extras?.wait_seconds;
  if (waitSeconds > 0) {
    return waitSeconds;
  }

  return DEFAULT_RATE_LIMIT_WAIT_SECONDS;
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
    dialog.alert({ message: trustHTML(errorInfo.message) });
  } else {
    dialog.alert(errorInfo.message);
  }
}
