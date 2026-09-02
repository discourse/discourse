import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { eq, notEq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import VoiceRoomForm from "discourse/plugins/voice/discourse/components/voice-room-form";
import roomIcon from "discourse/plugins/voice/discourse/lib/voice/room-icon";

export default class VoiceRoomInfoModal extends Component {
  @service voiceRooms;
  @service toasts;

  @tracked memberships = [];
  @tracked loading = false;
  @tracked selectedUsernames = [];
  @tracked selectedRole = "participant";
  @tracked addingMember = false;
  @tracked isEditing;

  constructor() {
    super(...arguments);
    this.isEditing = this.args.model.isEditing ?? false;
    if (this.showMembershipManagement && !this.isEditing) {
      this.loadMemberships();
    }
  }

  get room() {
    return this.args.model.room;
  }

  get showMembershipManagement() {
    return (
      this.room.can_manage &&
      (!this.room.public || this.room.room_type === "stage")
    );
  }

  get roleOptions() {
    const options = [
      {
        id: "participant",
        name: i18n("voice.room_info.members.participant"),
      },
    ];

    if (this.room.room_type === "stage") {
      options.push({
        id: "speaker",
        name: i18n("voice.room_info.members.speaker"),
      });
    }

    options.push({
      id: "moderator",
      name: i18n("voice.room_info.members.moderator"),
    });

    return options;
  }

  async loadMemberships() {
    this.loading = true;
    try {
      const result = await ajax(`/voice/rooms/${this.room.id}/memberships`);
      this.memberships = result.memberships;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  startEditing() {
    this.isEditing = true;
  }

  @action
  stopEditing() {
    this.isEditing = false;
    if (this.showMembershipManagement) {
      this.loadMemberships();
    }
  }

  @action
  async handleEdit(data) {
    try {
      const result = await ajax(`/voice/rooms/${this.room.id}`, {
        type: "PUT",
        data: { room: data },
      });
      this.voiceRooms.handleDirectoryEvent({
        type: "updated",
        room: result.room,
      });
      this.toasts.success({ data: { message: i18n("voice.room.updated") } });
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  setSelectedUsernames(usernames) {
    this.selectedUsernames = usernames;
  }

  @action
  setSelectedRole(role) {
    this.selectedRole = role;
  }

  @action
  async addMember() {
    if (!this.selectedUsernames.length) {
      return;
    }

    this.addingMember = true;
    try {
      for (const username of this.selectedUsernames) {
        await ajax(`/voice/rooms/${this.room.id}/memberships`, {
          type: "POST",
          data: { username, role: this.selectedRole },
        });
      }
      this.selectedUsernames = [];
      this.selectedRole = "participant";
      await this.loadMemberships();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.addingMember = false;
    }
  }

  @action
  async updateMemberRole(membership, role) {
    try {
      await ajax(`/voice/rooms/${this.room.id}/memberships/${membership.id}`, {
        type: "PUT",
        data: { role },
      });
      await this.loadMemberships();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async removeMember(membership) {
    try {
      await ajax(`/voice/rooms/${this.room.id}/memberships/${membership.id}`, {
        type: "DELETE",
      });
      await this.loadMemberships();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{if this.isEditing (i18n "voice.room.edit")}}
      class="voice-room-info-modal"
    >
      <:body>
        {{#if this.isEditing}}
          <div class="voice-room-info-modal__edit-form">
            <VoiceRoomForm
              @room={{this.room}}
              @onSubmit={{this.handleEdit}}
              @onManageMembers={{this.stopEditing}}
            />
          </div>
        {{else}}
          <div class="voice-room-info-modal__header">
            <div class="voice-room-info-modal__icon">
              {{dIcon (roomIcon this.room)}}
              {{#unless this.room.public}}
                {{dIcon "lock" class="voice-room-info-modal__icon-badge"}}
              {{/unless}}
            </div>
            <div class="voice-room-info-modal__header-content">
              <h2
                class="voice-room-info-modal__room-name"
              >{{this.room.name}}</h2>
              {{#if this.room.cooked_description}}
                <div
                  class="voice-room-info-modal__description cooked"
                >{{trustHTML this.room.cooked_description}}</div>
              {{/if}}
            </div>
            {{#if this.room.can_manage}}
              <DButton
                @action={{this.startEditing}}
                @icon="pencil"
                @title="voice.room.edit"
                class="btn-flat voice-room-info-modal__edit-btn"
              />
            {{/if}}
          </div>

          <div class="voice-room-info-modal__stats">
            <div class="voice-room-info-modal__stat">
              <span class="voice-room-info-modal__stat-value">
                {{#if this.room.public}}
                  {{dIcon "globe"}}
                {{else}}
                  {{dIcon "lock"}}
                {{/if}}
              </span>
              <span class="voice-room-info-modal__stat-label">
                {{if
                  this.room.public
                  (i18n "voice.room_info.public")
                  (i18n "voice.room_info.private")
                }}
              </span>
            </div>

            <div class="voice-room-info-modal__stat">
              <span
                class="voice-room-info-modal__stat-value"
              >{{this.room.member_count}}</span>
              <span class="voice-room-info-modal__stat-label">{{i18n
                  "voice.room_info.member_count"
                }}</span>
            </div>

            {{#if this.room.max_participants}}
              <div class="voice-room-info-modal__stat">
                <span
                  class="voice-room-info-modal__stat-value"
                >{{this.room.max_participants}}</span>
                <span class="voice-room-info-modal__stat-label">{{i18n
                    "voice.room_info.max_participants"
                  }}</span>
              </div>
            {{/if}}
          </div>

          {{#if this.showMembershipManagement}}
            <div class="voice-room-info-modal__members">
              <div class="voice-room-info-modal__section-header">
                {{dIcon "users"}}
                <h3>{{i18n "voice.room_info.members.title"}}</h3>
              </div>

              {{#if this.loading}}
                <div class="voice-room-info-modal__loading">
                  <div class="spinner small"></div>
                  {{i18n "loading"}}
                </div>
              {{else}}
                <div class="voice-room-info-modal__member-list">
                  {{#each this.memberships as |membership|}}
                    <div
                      class="voice-room-info-modal__member
                        {{if
                          (eq membership.user_id this.room.creator_id)
                          '--creator'
                        }}"
                    >
                      <div class="voice-room-info-modal__member-avatar">
                        {{dAvatar membership.user imageSize="medium"}}
                      </div>
                      <div class="voice-room-info-modal__member-details">
                        <span
                          class="voice-room-info-modal__member-username"
                        >{{membership.user.username}}</span>
                        {{#if (eq membership.user_id this.room.creator_id)}}
                          <span
                            class="voice-room-info-modal__member-role --creator"
                          >
                            {{dIcon "crown"}}
                            {{i18n "voice.room_info.members.creator"}}
                          </span>
                        {{else}}
                          <span
                            class="voice-room-info-modal__member-role --{{membership.role_name}}"
                          >
                            {{membership.role_name}}
                          </span>
                        {{/if}}
                      </div>

                      {{#if (notEq membership.user_id this.room.creator_id)}}
                        <div class="voice-room-info-modal__member-actions">
                          <ComboBox
                            @content={{this.roleOptions}}
                            @value={{membership.role_name}}
                            @onChange={{fn this.updateMemberRole membership}}
                            @options={{hash none=false}}
                            class="voice-room-info-modal__role-select"
                          />
                          <DButton
                            @action={{fn this.removeMember membership}}
                            @icon="xmark"
                            @title="voice.room_info.members.remove"
                            class="btn-flat btn-small voice-room-info-modal__remove-btn"
                          />
                        </div>
                      {{/if}}
                    </div>
                  {{/each}}
                </div>

                <div class="voice-room-info-modal__add-member">
                  <div class="voice-room-info-modal__add-row">
                    <UserChooser
                      @value={{this.selectedUsernames}}
                      @onChange={{this.setSelectedUsernames}}
                      @options={{hash
                        excludeCurrentUser=false
                        filterPlaceholder="voice.room_info.members.add_placeholder"
                      }}
                      class="voice-room-info-modal__user-chooser"
                    />
                    <ComboBox
                      @content={{this.roleOptions}}
                      @value={{this.selectedRole}}
                      @onChange={{this.setSelectedRole}}
                      @options={{hash none=false}}
                      class="voice-room-info-modal__role-chooser"
                    />
                    <DButton
                      @action={{this.addMember}}
                      @icon="plus"
                      @disabled={{this.addingMember}}
                      @title="voice.room_info.members.add_button"
                      class="btn-primary voice-room-info-modal__add-btn"
                    />
                  </div>
                </div>
              {{/if}}
            </div>
          {{/if}}
        {{/if}}
      </:body>
    </DModal>
  </template>
}
