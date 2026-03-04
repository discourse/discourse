import Controller from "@ember/controller";
import { computed } from "@ember/object";
import { i18n } from "discourse-i18n";

export default class UserInvitedController extends Controller {
  @computed("invitesCount.total", "invitesCount.pending")
  get pendingLabel() {
    if (this.invitesCount?.total > 0) {
      return i18n("user.invited.pending_tab_with_count", {
        count: this.invitesCount?.pending,
      });
    } else {
      return i18n("user.invited.pending_tab");
    }
  }

  @computed("invitesCount.total", "invitesCount.expired")
  get expiredLabel() {
    if (this.invitesCount?.total > 0) {
      return i18n("user.invited.expired_tab_with_count", {
        count: this.invitesCount?.expired,
      });
    } else {
      return i18n("user.invited.expired_tab");
    }
  }

  @computed("invitesCount.total", "invitesCount.redeemed")
  get redeemedLabel() {
    if (this.invitesCount?.total > 0) {
      return i18n("user.invited.redeemed_tab_with_count", {
        count: this.invitesCount?.redeemed,
      });
    } else {
      return i18n("user.invited.redeemed_tab");
    }
  }
}
