import { i18n } from "discourse-i18n";

export const STATUS_MODIFIERS = {
  would_import: "--import",
  imported: "--import",
  already_imported: "--update",
  updated: "--update",
  skipped: "--skip",
  failed: "--skip",
};

export function errorMessage(error) {
  return error ? i18n(`admin.rss_polling.test.errors.${error}`) : null;
}

export function itemNote(item) {
  switch (item.status) {
    case "already_imported":
      return i18n("admin.rss_polling.test.already_imported");
    case "updated":
      return i18n("admin.rss_polling.history.updated");
    case "failed":
      return i18n("admin.rss_polling.history.failed");
    case "skipped":
      return skipReason(item);
    default:
      return null;
  }
}

function skipReason(item) {
  if (!item.reason) {
    return null;
  }

  if (item.reason === "category_filter_mismatch") {
    return item.categories?.length
      ? i18n("admin.rss_polling.test.skip_reasons.category_filter_mismatch", {
          categories: item.categories.join(", "),
        })
      : i18n(
          "admin.rss_polling.test.skip_reasons.category_filter_mismatch_none"
        );
  }

  return i18n(`admin.rss_polling.test.skip_reasons.${item.reason}`);
}
