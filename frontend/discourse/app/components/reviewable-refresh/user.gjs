/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed, { bind } from "discourse/lib/decorators";
import { REJECTED } from "discourse/models/reviewable";
import ScrubRejectedUserModal from "admin/components/modal/scrub-rejected-user";
import LegacyReviewableUser from "../reviewable-user";

export default class ReviewableUser extends Component {
  @service currentUser;
  @service modal;
  @service store;

  @discourseComputed("reviewable.user_fields")
  userFields(fields) {
    return this.site.collectUserFields(fields);
  }

  @discourseComputed("reviewable.status", "currentUser", "isScrubbed")
  canScrubRejectedUser(status, currentUser, isScrubbed) {
    return status === REJECTED && currentUser.admin && !isScrubbed;
  }

  @discourseComputed("reviewable.payload")
  isScrubbed(payload) {
    return !!payload?.scrubbed_by;
  }

  @action
  showScrubRejectedUserModal() {
    this.modal.show(ScrubRejectedUserModal, {
      model: {
        confirmScrub: this.scrubRejectedUser,
      },
    });
  }

  @bind
  async scrubRejectedUser(reason) {
    try {
      await ajax({
        url: `/review/${this.reviewable.id}/scrub`,
        type: "PUT",
        data: { reason },
      });
      this.store.find("reviewable", this.reviewable.id);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <div class="review-item__meta-content">
      <LegacyReviewableUser @reviewable={{@reviewable}}>
        {{yield}}
      </LegacyReviewableUser>
    </div>
  </template>
}
