import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/avatar";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

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
        {{#if @claimedBy}}
          <div class="claimed-by">
            {{avatar @claimedBy imageSize="small"}}
            <span class="claimed-username">{{@claimedBy.username}}</span>
          </div>
          <DButton
            @icon="xmark"
            @action={{this.unclaim}}
            @title="review.unclaim.help"
            class="btn-small unclaim"
          />
        {{else}}
          <DButton
            @icon="user-plus"
            @title="review.claim.title"
            @action={{this.claim}}
            class="btn-small claim"
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
