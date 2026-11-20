import { i18n } from "discourse-i18n";

export default function confirmUserLocaleRemoval(
  dialog,
  siteSettings,
  previousValue,
  newValue,
  defaultLocale = siteSettings.default_locale
) {
  const localesFor = (value, locale) =>
    value === "all"
      ? (siteSettings.available_locales ?? []).map((item) => item.value)
      : [...(value ?? "").split("|").filter(Boolean), locale];
  const allowed = new Set(localesFor(newValue, defaultLocale));
  if (
    localesFor(previousValue, siteSettings.default_locale).every((locale) =>
      allowed.has(locale)
    )
  ) {
    return;
  }

  const prefix =
    "admin.site_settings.requires_confirmation_messages.allowed_user_locales";
  return dialog.confirm({
    message: i18n(`${prefix}.prompt`),
    confirmButtonLabel: `${prefix}.confirm`,
    cancelButtonLabel: "cancel_value",
  });
}
