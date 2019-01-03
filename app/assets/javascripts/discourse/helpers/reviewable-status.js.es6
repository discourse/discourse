import { htmlHelper } from "discourse-common/lib/helpers";
import { iconHTML } from "discourse-common/lib/icon-library";

import {
  PENDING,
  APPROVED,
  REJECTED,
  IGNORED,
  DELETED
} from "discourse/models/reviewable";

export function htmlStatus(status) {
  switch (status) {
    case PENDING:
      return I18n.t("review.statuses.pending.title");
    case APPROVED:
      return `${iconHTML("check")} ${I18n.t("review.statuses.approved.title")}`;
    case REJECTED:
      return `${iconHTML("times")} ${I18n.t("review.statuses.rejected.title")}`;
    case IGNORED:
      return `${iconHTML("external-link-alt")} ${I18n.t(
        "review.statuses.ignored.title"
      )}`;
    case DELETED:
      return `${iconHTML("trash")} ${I18n.t("review.statuses.deleted.title")}`;
  }
}

export default htmlHelper(status => {
  return htmlStatus(status);
});
