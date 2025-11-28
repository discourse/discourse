import { htmlSafe } from "@ember/template";
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
 * Get localized credit limit message based on user role and reset time.
 * Returns a raw string - wrap with htmlSafe() if needed for templates.
 *
 * @param {Object} options - Message options
 * @param {string} [options.resetTime] - When credits will reset (human-readable)
 * @param {boolean} [options.isAdmin] - Whether the current user is an admin
 * @returns {string} - Localized credit limit message
 */
export function getAiCreditLimitMessage({ resetTime, isAdmin } = {}) {
  const userType = isAdmin ? "admin" : "user";

  if (resetTime && resetTime.length > 0) {
    return i18n(`discourse_ai.errors.credit_limit_dialog.message_${userType}`, {
      reset_time: resetTime,
    });
  }

  return i18n(
    `discourse_ai.errors.credit_limit_dialog.message_without_time_${userType}`
  );
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

  const message = getAiCreditLimitMessage({
    resetTime,
    isAdmin: currentUser?.admin,
  });

  dialog.alert({
    title: i18n("discourse_ai.errors.credit_limit_dialog.title"),
    message: htmlSafe(message),
  });
}
