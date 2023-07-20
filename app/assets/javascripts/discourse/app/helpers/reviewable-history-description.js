import { EDITED } from "discourse/models/reviewable-history";
import I18n from "I18n";
import { htmlStatus } from "discourse/helpers/reviewable-status";
import { iconHTML } from "discourse-common/lib/icon-library";
import { htmlSafe } from "@ember/template";

export default function reviewableHistoryDescription(rh) {
  switch (rh.reviewable_history_type) {
    case EDITED:
      return htmlSafe(
        iconHTML("pencil-alt") + " " + I18n.t("review.history.edited")
      );
    default:
      return htmlSafe(htmlStatus(rh.status));
  }
}
