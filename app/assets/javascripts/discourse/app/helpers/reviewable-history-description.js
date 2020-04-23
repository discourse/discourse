import { htmlHelper } from "discourse-common/lib/helpers";
import { htmlStatus } from "discourse/helpers/reviewable-status";
import { EDITED } from "discourse/models/reviewable-history";
import { iconHTML } from "discourse-common/lib/icon-library";

export default htmlHelper(function(rh) {
  switch (rh.reviewable_history_type) {
    case EDITED:
      return iconHTML("pencil-alt") + " " + I18n.t("review.history.edited");
    default:
      return htmlStatus(rh.status);
  }
});
