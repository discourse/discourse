import Controller from "@ember/controller";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class UserInvitedController extends Controller {
  @discourseComputed("invitesCount.total", "invitesCount.pending")
  pendingLabel(invitesCountTotal, invitesCountPending) {
    if (invitesCountTotal > 0) {
      return i18n("user.invited.pending_tab_with_count", {
        count: invitesCountPending,
      });
    } else {
      return i18n("user.invited.pending_tab");
    }
  }

  @discourseComputed("invitesCount.total", "invitesCount.expired")
  expiredLabel(invitesCountTotal, invitesCountExpired) {
    if (invitesCountTotal > 0) {
      return i18n("user.invited.expired_tab_with_count", {
        count: invitesCountExpired,
      });
    } else {
      return i18n("user.invited.expired_tab");
    }
  }

  @discourseComputed("invitesCount.total", "invitesCount.redeemed")
  redeemedLabel(invitesCountTotal, invitesCountRedeemed) {
    if (invitesCountTotal > 0) {
      return i18n("user.invited.redeemed_tab_with_count", {
        count: invitesCountRedeemed,
      });
    } else {
      return i18n("user.invited.redeemed_tab");
    }
  }
}
