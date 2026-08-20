/**
 * Reports an error the application caught and chose to survive.
 * `ClientErrorHandlerService` logs it with the theme or plugin it came from
 * and shows admins a notice.
 *
 * @param error - The error that was caught.
 * @param messageKey - i18n key for the notice, by convention `broken_*_alert`.
 */
export function reportClientError(error: unknown, messageKey: string) {
  document.dispatchEvent(
    new CustomEvent("discourse-error", {
      detail: { messageKey, error },
    })
  );
}
