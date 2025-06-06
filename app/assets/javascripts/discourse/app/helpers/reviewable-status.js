import { htmlSafe } from "@ember/template";
import { iconHTML } from "discourse/lib/icon-library";
import {
  APPROVED,
  DELETED,
  IGNORED,
  PENDING,
  REJECTED,
} from "discourse/models/reviewable";
import { i18n } from "discourse-i18n";

function dataFor(status, type) {
  switch (status) {
    case PENDING:
      return { name: "pending" };
    case APPROVED:
      switch (type) {
        case "ReviewableQueuedPost":
          return {
            icon: "check",
            name: "approved_post",
            cssClass: "approved",
          };
        case "ReviewableUser":
          return {
            icon: "check",
            name: "approved_user",
            cssClass: "approved",
          };
        default:
          return {
            icon: "check",
            name: "approved_flag",
            cssClass: "approved",
          };
      }
    case REJECTED:
      switch (type) {
        case "ReviewableQueuedPost":
          return {
            icon: "xmark",
            name: "rejected_post",
            cssClass: "rejected",
          };
        case "ReviewableUser":
          return {
            icon: "xmark",
            name: "rejected_user",
            cssClass: "rejected",
          };
        default:
          return {
            icon: "xmark",
            name: "rejected_flag",
            cssClass: "rejected",
          };
      }
    case IGNORED:
      return {
        icon: "up-right-from-square",
        name: "ignored",
      };
    case DELETED:
      return { icon: "trash-can", name: "deleted" };
  }
}

/**
 * Returns a safe HTML string for a reviewable item status, given its status and type
 *
 * @param {number} status - The status of the reviewable item
 * @param {string} type - The type of the reviewable item
 * @returns {string} HTML for the reviewable item status
 */
export function newReviewableStatus(status, type) {
  let data = dataFor(status, type);
  if (!data) {
    return;
  }

  const html = `
    <div class="review-item__status --${data.cssClass || data.name}">
      ${i18n("review.statuses." + data.name + ".title")}
    </div>
  `;

  return htmlSafe(html);
}

export function htmlStatus(status, type) {
  let data = dataFor(status, type);
  if (!data) {
    return;
  }

  let icon = data.icon ? iconHTML(data.icon) : "";

  return `
    <span class="${data.cssClass || data.name}">
      ${icon}
      ${i18n("review.statuses." + data.name + ".title")}
    </span>
  `;
}

// TODO (reviewable-refresh): Replace with newReviewableStatus
export default function (status, type) {
  return htmlSafe(htmlStatus(status, type));
}
