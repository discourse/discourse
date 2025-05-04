import Component from "@ember/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ReviewableField from "discourse/components/reviewable-field";
import getUrl from "discourse/helpers/get-url";
import rawDate from "discourse/helpers/raw-date";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed, { bind } from "discourse/lib/decorators";
import { REJECTED } from "discourse/models/reviewable";
import { i18n } from "discourse-i18n";
import ScrubRejectedUserModal from "admin/components/modal/scrub-rejected-user";

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
    <div class="reviewable-user-info">
      <div class="reviewable-user-fields">
        {{#if this.isScrubbed}}
          <ReviewableField
            @classes="reviewable-user-details reject-reason"
            @name={{i18n "review.user.scrubbed_reject_reason"}}
            @value={{this.reviewable.reject_reason}}
          />

          <ReviewableField
            @classes="reviewable-user-details scrubbed-by"
            @name={{i18n "review.user.scrubbed_by"}}
            @value={{this.reviewable.payload.scrubbed_by}}
          />

          <ReviewableField
            @classes="reviewable-user-details scrubbed-reason"
            @name={{i18n "review.user.scrubbed_reason"}}
            @value={{this.reviewable.payload.scrubbed_reason}}
          />

          <ReviewableField
            @classes="reviewable-user-details scrubbed-at"
            @name={{i18n "review.user.scrubbed_at"}}
            @value={{rawDate this.reviewable.payload.scrubbed_at}}
          />
        {{else}}
          <div class="reviewable-user-details username">
            <div class="name">{{i18n "review.user.username"}}</div>
            <div class="value">
              {{#if this.reviewable.link_admin}}
                <a
                  href={{getUrl
                    (concat
                      "/admin/users/"
                      this.reviewable.user_id
                      "/"
                      this.reviewable.payload.username
                    )
                  }}
                >
                  {{this.reviewable.payload.username}}
                </a>
              {{else}}
                {{this.reviewable.payload.username}}
              {{/if}}
            </div>
          </div>
          <ReviewableField
            @classes="reviewable-user-details name"
            @name={{i18n "review.user.name"}}
            @value={{this.reviewable.payload.name}}
          />

          <ReviewableField
            @classes="reviewable-user-details email"
            @name={{i18n "review.user.email"}}
            @value={{this.reviewable.payload.email}}
          />

          <ReviewableField
            @classes="reviewable-user-details bio"
            @name={{i18n "review.user.bio"}}
            @value={{this.reviewable.payload.bio}}
          />

          {{#if this.reviewable.payload.website}}
            <div class="reviewable-user-details website">
              <div class="name">{{i18n "review.user.website"}}</div>
              <div class="value">
                <a
                  href={{this.reviewable.payload.website}}
                  target="_blank"
                  rel="noopener noreferrer"
                >{{this.reviewable.payload.website}}</a>
              </div>
            </div>
          {{/if}}

          <ReviewableField
            @classes="reviewable-user-details reject-reason"
            @name={{i18n "review.user.reject_reason"}}
            @value={{this.reviewable.reject_reason}}
          />

          {{#each this.userFields as |f|}}
            <ReviewableField
              @classes="reviewable-user-details user-field"
              @name={{f.name}}
              @value={{f.value}}
              @tagName=""
            />
          {{/each}}
        {{/if}}
      </div>

      {{yield}}
    </div>
    {{#if this.canScrubRejectedUser}}
      <div class="scrub-rejected-user">
        <button
          class="btn btn-danger"
          {{on "click" this.showScrubRejectedUserModal}}
        >
          {{i18n "review.user.scrub_record.button"}}
        </button>
      </div>
    {{/if}}
  </template>
}
