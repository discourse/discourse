import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { debounce } from "discourse/lib/decorators";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import ToggleInvitees from "../../toggle-invitees";
import User from "./user";

const RecurrenceScopeFilter = <template>
  <ul class="nav nav-pills invitees-recurrence-filter">
    <li>
      <button
        class={{if (eq @scope "this_event") "active"}}
        type="button"
        {{on "click" (fn @toggle "this_event")}}
      >
        {{i18n "discourse_post_event.invitees_modal.this_event"}}
      </button>
    </li>
    <li>
      <button
        class={{if (eq @scope "first_event_only") "active"}}
        type="button"
        {{on "click" (fn @toggle "first_event_only")}}
      >
        {{i18n "discourse_post_event.invitees_modal.first_event_only"}}
      </button>
    </li>
    <li>
      <button
        class={{if (eq @scope "this_and_following") "active"}}
        type="button"
        {{on "click" (fn @toggle "this_and_following")}}
      >
        {{i18n "discourse_post_event.models.invitee.this_and_following"}}
      </button>
    </li>
  </ul>
</template>;

export default class PostEventInviteesModal extends Component {
  @service discoursePostEventApi;

  @tracked filter;
  @tracked isLoading = false;
  @tracked recurrenceScope = "this_event";
  @tracked type = "going";
  @tracked inviteesList;

  constructor() {
    super(...arguments);
    this.fetchInvitees();
  }

  get hasSuggestedUsers() {
    return this.inviteesList?.suggestedUsers?.length > 0;
  }

  get hasResults() {
    return this.inviteesList?.invitees?.length > 0 || this.hasSuggestedUsers;
  }

  get title() {
    return i18n(
      `discourse_post_event.invitees_modal.${
        this.args.model.title || "title_invited"
      }`
    );
  }

  get recurringForNewInvitee() {
    if (!this.args.model.isRecurring || this.type !== "going") {
      return false;
    }

    return (
      this.recurrenceScope === "this_and_following" ||
      (this.recurrenceScope === "this_event" &&
        this.args.model.event.isFutureOccurrence)
    );
  }

  get showRecurrenceScopes() {
    return this.args.model.isRecurring && this.type === "going";
  }

  @action
  toggleType(type) {
    this.type = type;
    this.fetchInvitees(this.filter);
  }

  @action
  toggleRecurrenceScope(scope) {
    this.recurrenceScope = scope;
    this.fetchInvitees(this.filter);
  }

  @debounce(250)
  onFilterChanged(event) {
    this.filter = event.target.value;
    this.fetchInvitees(this.filter);
  }

  @action
  async removeInvitee(invitee) {
    await this.discoursePostEventApi.leaveEvent(this.args.model.event, invitee);

    this.inviteesList.remove(invitee);
  }

  @action
  async addInvitee(user) {
    const invitee = await this.discoursePostEventApi.joinEvent(
      this.args.model.event,
      {
        status: this.type,
        recurring: this.recurringForNewInvitee,
        user_id: user.id,
      }
    );

    this.inviteesList.add(invitee);
  }

  async fetchInvitees(filter) {
    try {
      this.isLoading = true;

      this.inviteesList = await this.discoursePostEventApi.listEventInvitees(
        this.args.model.event,
        {
          type: this.type,
          filter,
          recurrence_scope: this.recurrenceScope,
        }
      );
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <DModal
      class={{dConcatClass
        (or @model.extraClass "invited")
        "post-event-invitees-modal"
      }}
      @closeModal={{@closeModal}}
      @title={{this.title}}
    >
      <:body>
        <input
          class="filter"
          placeholder={{i18n
            "discourse_post_event.invitees_modal.filter_placeholder"
          }}
          type="text"
          {{on "input" this.onFilterChanged}}
        />

        <ToggleInvitees @toggle={{this.toggleType}} @viewType={{this.type}} />
        {{#if this.showRecurrenceScopes}}
          <RecurrenceScopeFilter
            @scope={{this.recurrenceScope}}
            @toggle={{this.toggleRecurrenceScope}}
          />
        {{/if}}
        <DConditionalLoadingSpinner @condition={{this.isLoading}}>
          {{#if this.hasResults}}
            <ul class="invitees">
              {{#each this.inviteesList.invitees as |invitee|}}
                <li class="invitee">
                  <User @user={{invitee.user}} />

                  {{#if @model.event.canActOnDiscoursePostEvent}}
                    <DButton
                      class="btn-transparent btn-danger remove-invitee"
                      title={{i18n
                        "discourse_post_event.invitees_modal.remove_invitee"
                      }}
                      @action={{fn this.removeInvitee invitee}}
                      @icon="trash-can"
                    />
                  {{/if}}
                </li>
              {{/each}}
            </ul>
            {{#if this.hasSuggestedUsers}}
              <ul class="possible-invitees">
                {{#each this.inviteesList.suggestedUsers as |user|}}
                  <li class="invitee">
                    <User @user={{user}} />

                    {{#if @model.event.canActOnDiscoursePostEvent}}
                      <DButton
                        class="btn-default add-invitee"
                        title={{i18n
                          "discourse_post_event.invitees_modal.add_invitee"
                        }}
                        @action={{fn this.addInvitee user}}
                        @icon="plus"
                      />
                    {{/if}}
                  </li>
                {{/each}}
              </ul>
            {{/if}}
          {{else}}
            <p class="no-users">
              {{i18n "discourse_post_event.models.invitee.no_users"}}
            </p>
          {{/if}}
        </DConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
