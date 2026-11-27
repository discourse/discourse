import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ScrubRejectedUserModal from "discourse/admin/components/modal/scrub-rejected-user";
import ReviewableField from "discourse/components/reviewable-field";
import rawDate from "discourse/helpers/raw-date";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { longDate } from "discourse/lib/formatter";
import getUrl from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class ReviewableUser extends Component {
  @service modal;
  @service site;
  @service store;

  get userFields() {
    return this.site.collectUserFields(this.args.reviewable?.user_fields);
  }

  get isScrubbed() {
    return !!this.args.reviewable?.payload?.scrubbed_by;
  }

  get silencedTill() {
    return this.penaltyDate(this.args.reviewable?.target_user?.silenced_till);
  }

  get suspendedTill() {
    return this.penaltyDate(this.args.reviewable?.target_user?.suspended_till);
  }

  penaltyDate(date) {
    if (!date) {
      return;
    }

    return moment().diff(date, "years") < -100
      ? i18n("review.user.penalty_forever")
      : longDate(date);
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
        url: `/review/${this.args.reviewable.id}/scrub`,
        type: "PUT",
        data: { reason },
      });
      this.store.find("reviewable", this.args.reviewable.id);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <div class="review-item__meta-content">
      <div class="reviewable-user-info">
        <div class="reviewable-user-fields">
          {{#if this.isScrubbed}}
            <ReviewableField
              @classes="reviewable-user-details reject-reason"
              @name={{i18n "review.user.scrubbed_reject_reason"}}
              @value={{@reviewable.reject_reason}}
            />

            <ReviewableField
              @classes="reviewable-user-details scrubbed-by"
              @name={{i18n "review.user.scrubbed_by"}}
              @value={{@reviewable.payload.scrubbed_by}}
            />

            <ReviewableField
              @classes="reviewable-user-details scrubbed-reason"
              @name={{i18n "review.user.scrubbed_reason"}}
              @value={{@reviewable.payload.scrubbed_reason}}
            />

            <ReviewableField
              @classes="reviewable-user-details scrubbed-at"
              @name={{i18n "review.user.scrubbed_at"}}
              @value={{rawDate @reviewable.payload.scrubbed_at}}
            />
          {{else}}
            <div class="reviewable-user-details username">
              <div class="name">{{i18n "review.user.username"}}</div>
              <div class="value">
                {{#if @reviewable.link_admin}}
                  <a
                    href={{getUrl
                      (concat
                        "/admin/users/"
                        @reviewable.user.id
                        "/"
                        @reviewable.payload.username
                      )
                    }}
                  >
                    {{@reviewable.payload.username}}
                  </a>
                {{else}}
                  {{@reviewable.payload.username}}
                {{/if}}
              </div>
            </div>
            {{#if @reviewable.target_user.silenced_till}}
              <ReviewableField
                @classes="reviewable-user-details silenced-till"
                @name={{i18n "review.user.silenced_until"}}
                @value={{this.silencedTill}}
              />
              <ReviewableField
                @classes="reviewable-user-details silence-reason"
                @name={{i18n "review.user.silence_reason"}}
                @value={{@reviewable.target_user.silence_reason}}
              />
            {{/if}}

            {{#if @reviewable.target_user.suspended_till}}
              <ReviewableField
                @classes="reviewable-user-details suspended-till"
                @name={{i18n "review.user.suspended_until"}}
                @value={{this.suspendedTill}}
              />
              <ReviewableField
                @classes="reviewable-user-details suspend-reason"
                @name={{i18n "review.user.suspend_reason"}}
                @value={{@reviewable.target_user.suspend_reason}}
              />
            {{/if}}

            {{#if @reviewable.payload.avatar_url}}
              <div class="reviewable-user-details avatar">
                <div class="name">{{i18n "review.user.avatar"}}</div>
                <div class="value">
                  <img
                    alt={{i18n "review.user.avatar"}}
                    class="reviewable-user-avatar"
                    loading="lazy"
                    src={{@reviewable.payload.avatar_url}}
                  />
                </div>
              </div>
            {{/if}}

            <ReviewableField
              @classes="reviewable-user-details name"
              @name={{i18n "review.user.name"}}
              @value={{@reviewable.payload.name}}
            />

            <ReviewableField
              @classes="reviewable-user-details email"
              @name={{i18n "review.user.email"}}
              @value={{@reviewable.payload.email}}
            />

            <ReviewableField
              @classes="reviewable-user-details bio"
              @name={{i18n "review.user.bio"}}
              @value={{@reviewable.payload.bio}}
            />

            {{#if @reviewable.payload.website}}
              <div class="reviewable-user-details website">
                <div class="name">{{i18n "review.user.website"}}</div>
                <div class="value">
                  <a
                    href={{@reviewable.payload.website}}
                    rel="noopener noreferrer"
                    target="_blank"
                  >{{@reviewable.payload.website}}</a>
                </div>
              </div>
            {{/if}}

            <ReviewableField
              @classes="reviewable-user-details reject-reason"
              @name={{i18n "review.user.reject_reason"}}
              @value={{@reviewable.reject_reason}}
            />

            {{#each this.userFields as |f|}}
              <ReviewableField
                @classes="reviewable-user-details user-field"
                @name={{f.name}}
                @value={{f.value}}
              />
            {{/each}}
          {{/if}}
        </div>

        {{yield}}
      </div>
    </div>
  </template>
}
