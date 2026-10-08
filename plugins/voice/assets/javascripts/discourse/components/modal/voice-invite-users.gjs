import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { durationTiny } from "discourse/lib/formatter";
import { clipboardCopy } from "discourse/lib/utilities";
import UserChooser from "discourse/select-kit/components/user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class VoiceInviteUsersModal extends Component {
  @service currentUser;
  @service router;
  @service toasts;

  @tracked suggestions = [];
  @tracked loadingSuggestions = true;
  @tracked selectedUsernames = [];
  @tracked invitedUsernames = [];
  @tracked inviting = false;

  constructor() {
    super(...arguments);
    this.loadSuggestions();
  }

  get room() {
    return this.args.model.room;
  }

  get inviteUrl() {
    const url = this.router.urlFor(
      "voice-room-invite",
      this.room.slug,
      this.currentUser.username_lower
    );
    return new URL(url, window.location.origin).href;
  }

  get suggestionRows() {
    return this.suggestions.map((suggestion) => ({
      ...suggestion,
      timeTogether: durationTiny(suggestion.total_seconds),
      invited: this.invitedUsernames.includes(suggestion.username),
    }));
  }

  async loadSuggestions() {
    try {
      const result = await ajax(
        `/voice/rooms/${this.room.id}/invites/suggestions`
      );
      this.suggestions = result.suggestions;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loadingSuggestions = false;
    }
  }

  @action
  setSelectedUsernames(usernames) {
    this.selectedUsernames = usernames;
  }

  @action
  async inviteSelected() {
    if (!this.selectedUsernames.length) {
      return;
    }
    await this.#invite(this.selectedUsernames);
    this.selectedUsernames = [];
  }

  @action
  async inviteSuggestion(suggestion) {
    await this.#invite([suggestion.username]);
  }

  @action
  copyLink() {
    clipboardCopy(this.inviteUrl);
    this.toasts.success({
      duration: "short",
      data: { message: i18n("voice.room.link_copied") },
    });
  }

  async #invite(usernames) {
    this.inviting = true;
    try {
      const result = await ajax(`/voice/rooms/${this.room.id}/invites`, {
        type: "POST",
        data: { usernames },
      });
      this.invitedUsernames = [
        ...this.invitedUsernames,
        ...result.invited_usernames,
      ];
      if (result.invited_usernames.length) {
        this.toasts.success({
          duration: "short",
          data: {
            message: i18n("voice.invite.sent", {
              count: result.invited_usernames.length,
            }),
          },
        });
      }
      if (result.skipped_usernames.length) {
        this.toasts.warning({
          data: {
            message: i18n("voice.invite.skipped", {
              usernames: result.skipped_usernames
                .map((username) => `@${username}`)
                .join(", "),
            }),
          },
        });
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.inviting = false;
    }
  }

  <template>
    <DModal
      class="voice-invite-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "voice.invite.title" room_name=this.room.name}}
    >
      <:body>
        <div class="voice-invite-modal__search">
          <span class="voice-invite-modal__label">
            {{i18n "voice.invite.search_label"}}
          </span>
          <div class="voice-invite-modal__search-row">
            <UserChooser
              class="voice-invite-modal__user-chooser"
              @onChange={{this.setSelectedUsernames}}
              @options={{hash
                excludeCurrentUser=true
                filterPlaceholder="voice.invite.search_placeholder"
              }}
              @value={{this.selectedUsernames}}
            />
            <DButton
              class="btn-primary voice-invite-modal__send"
              @action={{this.inviteSelected}}
              @disabled={{this.inviting}}
              @icon="paper-plane"
              @label="voice.invite.send"
            />
          </div>
        </div>

        {{#if this.loadingSuggestions}}
          <div class="voice-invite-modal__loading">
            <div class="spinner small"></div>
            {{i18n "loading"}}
          </div>
        {{else if this.suggestionRows.length}}
          <div class="voice-invite-modal__suggestions">
            <h3 class="voice-invite-modal__section-title">
              {{i18n "voice.invite.suggestions_title"}}
            </h3>
            <div class="voice-invite-modal__suggestion-list">
              {{#each this.suggestionRows as |suggestion|}}
                <div class="voice-invite-modal__suggestion">
                  <div class="voice-invite-modal__suggestion-avatar">
                    {{dAvatar suggestion imageSize="medium"}}
                  </div>
                  <div class="voice-invite-modal__suggestion-details">
                    <span
                      class="voice-invite-modal__suggestion-username"
                    >{{suggestion.username}}</span>
                    <span class="voice-invite-modal__suggestion-time">
                      {{i18n
                        "voice.invite.time_together"
                        duration=suggestion.timeTogether
                      }}
                    </span>
                  </div>
                  {{#if suggestion.invited}}
                    <span class="voice-invite-modal__suggestion-invited">
                      {{dIcon "check"}}
                      {{i18n "voice.invite.invited"}}
                    </span>
                  {{else}}
                    <DButton
                      class="btn-small voice-invite-modal__suggestion-invite"
                      @action={{fn this.inviteSuggestion suggestion}}
                      @disabled={{this.inviting}}
                      @icon="user-plus"
                      @label="voice.invite.invite"
                    />
                  {{/if}}
                </div>
              {{/each}}
            </div>
          </div>
        {{/if}}

        <div class="voice-invite-modal__link">
          <label class="voice-invite-modal__label" for="voice-invite-link">
            {{i18n "voice.invite.link_label"}}
          </label>
          <div class="voice-invite-modal__link-row">
            <input
              class="voice-invite-modal__link-input"
              id="voice-invite-link"
              readonly
              type="text"
              value={{this.inviteUrl}}
            />
            <DButton
              class="voice-invite-modal__copy"
              @action={{this.copyLink}}
              @icon="copy"
              @label="voice.invite.copy"
            />
          </div>
        </div>
      </:body>
    </DModal>
  </template>
}
