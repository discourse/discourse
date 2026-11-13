import DismissReadModal from "discourse/components/modal/dismiss-read";
import { i18n } from "discourse-i18n";

/**
 * Wording and options shared by the ways a topic list offers dismissing, so
 * its buttons and the tab bar's options menu stay alike.
 */

/**
 * @param {Object} model The topic list.
 * @returns {string|undefined} Which part of the new list is showing.
 */
export function newListSubset(model) {
  return model?.params?.subset ?? model?.listParams?.subset;
}

/**
 * @param {number} selectedCount How many topics are bulk selected.
 * @returns {string}
 */
export function dismissReadLabel(selectedCount) {
  if (selectedCount === 0) {
    return i18n("topics.bulk.dismiss_button");
  }

  return i18n("topics.bulk.dismiss_button_with_selected", {
    count: selectedCount,
  });
}

/**
 * @param {Object} options
 * @param {boolean} options.unifiedNew Whether new topics and replies share a
 * list.
 * @param {string} [options.subset] From `newListSubset`.
 * @param {number} options.selectedCount How many topics are bulk selected.
 * @returns {string}
 */
export function dismissNewLabel({ unifiedNew, subset, selectedCount }) {
  const selected = selectedCount > 0;

  if (unifiedNew) {
    switch (subset) {
      case "topics":
        return selected
          ? i18n("topics.bulk.dismiss_new_topics_with_selected", {
              count: selectedCount,
            })
          : i18n("topics.bulk.dismiss_new_topics");
      case "replies":
        return selected
          ? i18n("topics.bulk.dismiss_new_replies_with_selected", {
              count: selectedCount,
            })
          : i18n("topics.bulk.dismiss_new_replies");
      default:
        return selected
          ? i18n("topics.bulk.dismiss_all_with_selected", {
              count: selectedCount,
            })
          : i18n("topics.bulk.dismiss_all");
    }
  }

  return selected
    ? i18n("topics.bulk.dismiss_new_with_selected", { count: selectedCount })
    : i18n("topics.bulk.dismiss_new");
}

/**
 * @param {string} [subset] From `newListSubset`.
 * @returns {{dismissPosts: boolean, dismissTopics: boolean, untrack: boolean}}
 * What dismissing the showing part of the new list clears.
 */
export function dismissNewOptions(subset) {
  return {
    dismissPosts: subset !== "topics",
    dismissTopics: subset !== "replies",
    untrack: false,
  };
}

/**
 * @param {string} [subset] From `newListSubset`.
 * @returns {boolean} Whether dismissing can also stop tracking, which only
 * replies are tracked for.
 */
export function canDismissNewAndStopTracking(subset) {
  return subset !== "topics";
}

/**
 * Asks which read topics to dismiss.
 *
 * @param {Object} modal The modal service.
 * @param {Object} options
 * @param {number} options.selectedCount How many topics are bulk selected.
 * @param {Function} options.dismissRead Dismisses them.
 */
export function showDismissReadModal(modal, { selectedCount, dismissRead }) {
  modal.show(DismissReadModal, {
    model: {
      title: selectedCount
        ? "topics.bulk.dismiss_read_with_selected"
        : "topics.bulk.dismiss_read",
      count: selectedCount,
      dismissRead,
    },
  });
}
