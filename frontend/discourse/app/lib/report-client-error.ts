/**
 * Reports an error the application caught and chose to survive.
 *
 * `ClientErrorHandlerService` picks these up, logs them with the theme or plugin they came
 * from, and shows admins a notice. Callers keep their own control flow: what to return,
 * whether to carry on, and whether to also surface the error in tests.
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
