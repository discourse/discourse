import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class ReviewableClaimedTopic extends Component {
  @service currentUser;
  @service siteSettings;
  @service store;

  get enabled() {
    return this.siteSettings.reviewable_claiming !== "disabled";
  }

  get isRefresh() {
    return this.siteSettings.reviewable_ui_refresh;
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
            @icon="xmark"
            @action={{this.unclaim}}
            @title={{unless this.isRefresh "review.unclaim.help"}}
            @label={{if this.isRefresh "review.unclaim.help"}}
            class="btn-default unclaim"
          />
        {{else}}
          <DButton
            @icon="user-plus"
            @title={{if
              this.isRefresh
              "review.claim_help.optional"
              "review.claim.title"
            }}
            @label={{if this.isRefresh "review.claim.title"}}
            @action={{this.claim}}
            class="btn-default claim"
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
