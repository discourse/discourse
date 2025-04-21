import { htmlSafe } from "@ember/template";
import { htmlStatus } from "discourse/helpers/reviewable-status";
import { iconHTML } from "discourse/lib/icon-library";
import { EDITED } from "discourse/models/reviewable-history";
import { i18n } from "discourse-i18n";

export default function reviewableHistoryDescription(rh) {
  switch (rh.reviewable_history_type) {
    case EDITED:
      return htmlSafe(iconHTML("pencil") + " " + i18n("review.history.edited"));
    default:
      return htmlSafe(htmlStatus(rh.status));
  }
}
