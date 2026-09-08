import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";

export default class ReviewableClaimedTopic extends Component {
  @service currentUser;
  @service siteSettings;
  @service store;

  get enabled() {
    return this.siteSettings.reviewable_claiming !== "disabled";
  }

  @action
  async unclaim() {
    try {
      await ajax(`/reviewable_claimed_topics/${this.args.topicId}`, {
        type: "DELETE",
      });
      this.args.onClaim(null);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async claim() {
    const claim = this.store.createRecord("reviewable-claimed-topic");

    try {
      await claim.save({ topic_id: this.args.topicId });
      this.args.onClaim({
        user: this.currentUser,
        automatic: false,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    {{#if this.enabled}}
      <div class="reviewable-claimed-topic">
        {{#if @claimedBy.user}}
          <DButton
            class="btn-default unclaim"
            @action={{this.unclaim}}
            @icon="xmark"
            @label="review.unclaim.help"
          />
        {{else}}
          <DButton
            class="btn-default claim"
            @action={{this.claim}}
            @icon="user-plus"
            @label="review.claim.title"
            @title="review.claim_help.optional"
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
