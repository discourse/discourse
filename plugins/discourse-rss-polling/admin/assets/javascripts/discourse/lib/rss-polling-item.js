import { tracked } from "@glimmer/tracking";
import { trustHTML } from "@ember/template";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import RssPollingFeedSettings from "../../admin/models/rss-polling-feed-settings";

async function setFeedEnabled(feed, enabled, toasts) {
  await RssPollingFeedSettings.setEnabled(feed, enabled);
  feed.enabled = enabled;
  toasts.success({
    duration: "short",
    data: {
      message: i18n(
        enabled
          ? "admin.rss_polling.feeds.enable_success"
          : "admin.rss_polling.feeds.disable_success"
      ),
    },
  });
}

export class FeedEnabledToggle {
  @tracked optimisticEnabled = null;

  toggle = async () => {
    if (this.optimisticEnabled !== null) {
      return;
    }

    const enabled = !this.enabled;
    this.optimisticEnabled = enabled;

    try {
      await setFeedEnabled(this.feed, enabled, this.toasts);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.optimisticEnabled = null;
    }
  };

  constructor(feed, toasts) {
    this.feed = feed;
    this.toasts = toasts;
  }

  get enabled() {
    return this.optimisticEnabled ?? this.feed?.enabled;
  }
}

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

export function pollSummary(attempt) {
  const parts = ["imported", "updated", "skipped", "failed"]
    .filter((name) => attempt[`${name}_count`] > 0)
    .map((name) =>
      i18n(`admin.rss_polling.history.${name}_count`, {
        count: attempt[`${name}_count`],
      })
    );

  if (parts.length) {
    return parts.join(" · ");
  }

  return attempt.error
    ? errorMessage(attempt.error)
    : i18n("admin.rss_polling.history.no_changes");
}

export function previewSummary(items) {
  const tally = (items ?? []).reduce((acc, item) => {
    acc[item.status] = (acc[item.status] ?? 0) + 1;
    return acc;
  }, {});

  return ["would_import", "already_imported", "skipped"]
    .filter((status) => tally[status])
    .map((status) =>
      i18n(`admin.rss_polling.test.summary.${status}`, { count: tally[status] })
    )
    .join(" · ");
}

export function itemNote(item) {
  switch (item.status) {
    case "would_import":
      return i18n("admin.rss_polling.test.would_import");
    case "already_imported":
      return topicNote(item, "admin.rss_polling.test.already_imported");
    case "imported":
      return topicNote(item, "admin.rss_polling.history.imported");
    case "updated":
      return topicNote(item, "admin.rss_polling.history.updated");
    case "failed":
      return failReason(item);
    case "skipped":
      return skipReason(item);
    default:
      return null;
  }
}

function failReason(item) {
  if (!item.reason) {
    return i18n("admin.rss_polling.history.failed");
  }

  if (item.reason === "import_rejected") {
    return i18n("admin.rss_polling.history.failed_reasons.import_rejected");
  }

  return i18n("admin.rss_polling.history.failed_reasons.import_error", {
    error: item.reason,
  });
}

function topicNote(item, messageKey) {
  if (!item.topic_url) {
    return i18n(`${messageKey}_plain`);
  }

  return trustHTML(
    i18n(messageKey, { topic_url: escapeExpression(item.topic_url) })
  );
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
