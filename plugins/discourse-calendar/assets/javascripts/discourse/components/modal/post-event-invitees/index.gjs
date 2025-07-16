import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import concatClass from "discourse/helpers/concat-class";
import { debounce } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ToggleInvitees from "../../toggle-invitees";
import User from "./user";

export default class PostEventInviteesModal extends Component {
  @service store;
  @service discoursePostEventApi;

  @tracked filter;
  @tracked isLoading = false;
  @tracked type = "going";
  @tracked inviteesList;

  constructor() {
    super(...arguments);
    this._fetchInvitees();
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

  @action
  toggleType(type) {
    this.type = type;
    this._fetchInvitees(this.filter);
  }

  @debounce(250)
  onFilterChanged(event) {
    this.filter = event.target.value;
    this._fetchInvitees(this.filter);
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
        user_id: user.id,
      }
    );

    this.inviteesList.add(invitee);
  }

  async _fetchInvitees(filter) {
    try {
      this.isLoading = true;

      this.inviteesList = await this.discoursePostEventApi.listEventInvitees(
        this.args.model.event,
        { type: this.type, filter }
      );
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <DModal
      @title={{this.title}}
      @closeModal={{@closeModal}}
      class={{concatClass
        (or @model.extraClass "invited")
        "post-event-invitees-modal"
      }}
    >
      <:body>
        <input
          {{on "input" this.onFilterChanged}}
          type="text"
          placeholder={{i18n
            "discourse_post_event.invitees_modal.filter_placeholder"
          }}
          class="filter"
        />

        <ToggleInvitees @viewType={{this.type}} @toggle={{this.toggleType}} />
        <ConditionalLoadingSpinner @condition={{this.isLoading}}>
          {{#if this.hasResults}}
            <ul class="invitees">
              {{#each this.inviteesList.invitees as |invitee|}}
                <li class="invitee">
                  <User @user={{invitee.user}} />
                  {{#if @model.event.canActOnDiscoursePostEvent}}
                    <DButton
                      class="remove-invitee"
                      @icon="trash-can"
                      @action={{fn this.removeInvitee invitee}}
                      title={{i18n
                        "discourse_post_event.invitees_modal.remove_invitee"
                      }}
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
                    <DButton
                      class="add-invitee"
                      @icon="plus"
                      @action={{fn this.addInvitee user}}
                      title={{i18n
                        "discourse_post_event.invitees_modal.add_invitee"
                      }}
                    />
                  </li>
                {{/each}}
              </ul>
            {{/if}}
          {{else}}
            <p class="no-users">
              {{i18n "discourse_post_event.models.invitee.no_users"}}
            </p>
          {{/if}}
        </ConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
