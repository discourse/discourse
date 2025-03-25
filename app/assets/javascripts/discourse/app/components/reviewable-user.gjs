import Component from "@ember/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ReviewableField from "discourse/components/reviewable-field";
import getUrl from "discourse/helpers/get-url";
import discourseComputed from "discourse/lib/decorators";
import { REJECTED } from "discourse/models/reviewable";
import { i18n } from "discourse-i18n";
import DeleteRejectedUserModal from "admin/components/modal/delete-rejected-user";

export default class ReviewableUser extends Component {
  @service modal;

  @discourseComputed("reviewable.user_fields")
  userFields(fields) {
    return this.site.collectUserFields(fields);
  }

  @discourseComputed("reviewable.status")
  isRejected(status) {
    return status === REJECTED;
  }

  @action
  showDeleteRejectedUserModal() {
    this.modal.show(DeleteRejectedUserModal, {
      model: {
        confirmDelete: this.deleteRejectedUser.bind(this),
      },
    });
  }

  deleteRejectedUser() {
    // this.reviewable.destroyRecord();
  }

  <template>
    <div class="reviewable-user-info">
      <div class="reviewable-user-fields">
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
      </div>

      {{yield}}
    </div>
    {{#if this.isRejected}}
      <div class="delete-rejected-user">
        <button
          class="btn btn-danger"
          {{on "click" this.showDeleteRejectedUserModal}}
        >
          {{i18n "review.user.delete_record.button"}}
        </button>
      </div>
    {{/if}}
  </template>
}
