import { htmlSafe } from "@ember/template";
import { htmlStatus } from "discourse/helpers/reviewable-status";
import { EDITED } from "discourse/models/reviewable-history";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "discourse-i18n";

export default function reviewableHistoryDescription(rh) {
  switch (rh.reviewable_history_type) {
    case EDITED:
      return htmlSafe(
        iconHTML("pencil") + " " + I18n.t("review.history.edited")
      );
    default:
      return htmlSafe(htmlStatus(rh.status));
  }
}
