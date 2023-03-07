import {
  APPROVED,
  DELETED,
  IGNORED,
  PENDING,
  REJECTED,
} from "discourse/models/reviewable";
import I18n from "I18n";
import { htmlHelper } from "discourse-common/lib/helpers";
import { iconHTML } from "discourse-common/lib/icon-library";

function dataFor(status, type) {
  switch (status) {
    case PENDING:
      return { name: "pending" };
    case APPROVED:
      switch (type) {
        case "Queued Post":
        case "ReviewableQueuedPost":
          return { icon: "check", name: "approved_post" };
        case "User":
          return { icon: "check", name: "approved_user" };
        default:
          return { icon: "check", name: "approved_flag" };
      }
    case REJECTED:
      switch (type) {
        case "Queued Post":
        case "ReviewableQueuedPost":
          return { icon: "times", name: "rejected_post" };
        case "User":
          return { icon: "times", name: "rejected_user" };
        default:
          return { icon: "times", name: "rejected_flag" };
      }
    case IGNORED:
      return { icon: "external-link-alt", name: "ignored" };
    case DELETED:
      return { icon: "trash-alt", name: "deleted" };
  }
}

export function htmlStatus(status, type) {
  let data = dataFor(status, type);
  if (!data) {
    return;
  }

  let icon = data.icon ? iconHTML(data.icon) : "";

  return `
      <span class="${data.name}">
        ${icon}
        ${I18n.t("review.statuses." + data.name + ".title")}
      </span>
  `;
}

export default htmlHelper((status, type) => {
  return htmlStatus(status, type);
});
