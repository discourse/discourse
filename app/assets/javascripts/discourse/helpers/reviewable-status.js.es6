import { htmlHelper } from "discourse-common/lib/helpers";
import { iconHTML } from "discourse-common/lib/icon-library";
import {
  PENDING,
  APPROVED,
  REJECTED,
  IGNORED,
  DELETED
} from "discourse/models/reviewable";

function dataFor(status) {
  switch (status) {
    case PENDING:
      return { name: "pending" };
    case APPROVED:
      return { icon: "check", name: "approved" };
    case REJECTED:
      return { icon: "times", name: "rejected" };
    case IGNORED:
      return { icon: "external-link-alt", name: "ignored" };
    case DELETED:
      return { icon: "trash-alt", name: "deleted" };
  }
}

export function htmlStatus(status) {
  let data = dataFor(status);
  if (!data) {
    return;
  }

  let icon = data.icon ? iconHTML(data.icon) : "";

  return `
    <span class='status'>
      <span class="${data.name}">
        ${icon}
        ${I18n.t("review.statuses." + data.name + ".title")}
      </span>
    </span>
  `;
}

export default htmlHelper(status => {
  return htmlStatus(status);
});
