import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { i18n } from "discourse-i18n";

/**
 * Check if an error/payload is an AI credit limit error.
 * Works with both AJAX errors and MessageBus payloads.
 *
 * @param {Object} errorOrPayload - AJAX error object or MessageBus payload
 * @returns {boolean} - True if this is a credit limit error
 */
export function isAiCreditLimitError(errorOrPayload) {
  if (!errorOrPayload) {
    return false;
  }

  // AJAX error format:
  if (errorOrPayload.jqXHR?.responseJSON?.error === "credit_limit_exceeded") {
    return true;
  }

  // MessageBus payload format:
  if (errorOrPayload.error_type === "credit_limit_exceeded") {
    return true;
  }

  // Direct error object:
  if (errorOrPayload.error === "credit_limit_exceeded") {
    return true;
  }

  return false;
}

/**
 * Show credit limit dialog to user.
 * Similar to popupAjaxError but specialized for AI credit limits.
 *
 * @param {Object} errorOrPayload - AJAX error or MessageBus payload
 */
export function popupAiCreditLimitError(errorOrPayload) {
  const dialog = getOwnerWithFallback(this).lookup("service:dialog");
  const currentUser = getOwnerWithFallback(this).lookup("service:current-user");

  const details =
    errorOrPayload.jqXHR?.responseJSON?.details || errorOrPayload.details || {};

  const resetTime =
    details?.reset_time_absolute ||
    details?.reset_time_relative ||
    details?.reset_time;

  // Choose message key based on user role
  const userType = currentUser?.admin ? "admin" : "user";
  let message;

  if (resetTime && resetTime.length > 0) {
    message = i18n(
      `discourse_ai.errors.credit_limit_dialog.message_${userType}`,
      {
        reset_time: resetTime,
      }
    );
  } else {
    message = i18n(
      `discourse_ai.errors.credit_limit_dialog.message_without_time_${userType}`
    );
  }

  dialog.alert({
    title: i18n("discourse_ai.errors.credit_limit_dialog.title"),
    message,
  });
}
