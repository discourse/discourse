import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { homepageNavigationDestination } from "discourse/lib/homepage-router-overrides";
import { escapeExpression } from "discourse/lib/utilities";
import ComboBox from "discourse/select-kit/components/combo-box";
import UserChooser from "discourse/select-kit/components/user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import LiveRoomForm from "discourse/plugins/live/discourse/components/live-room-form";
import roomIcon from "discourse/plugins/live/discourse/lib/live/room-icon";

export default class LiveRoomInfoModal extends Component {
  @service dialog;
  @service liveRooms;
  @service liveWebrtc;
  @service router;
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
        name: i18n("live.room_info.members.participant"),
      },
    ];

    if (this.room.room_type === "stage") {
      options.push({
        id: "speaker",
        name: i18n("live.room_info.members.speaker"),
      });
    }

    options.push({
      id: "moderator",
      name: i18n("live.room_info.members.moderator"),
    });

    return options;
  }

  async loadMemberships() {
    this.loading = true;
    try {
      const result = await ajax(`/live/rooms/${this.room.id}/memberships`);
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
      const result = await ajax(`/live/rooms/${this.room.id}`, {
        type: "PUT",
        data: { room: data },
      });
      this.liveRooms.handleDirectoryEvent({
        type: "updated",
        room: result.room,
      });
      this.toasts.success({ data: { message: i18n("live.room.updated") } });
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  deleteRoom() {
    const room = this.room;

    this.dialog.deleteConfirm({
      message: i18n("live.room.delete_confirm", {
        name: escapeExpression(room.name),
      }),
      didConfirm: async () => {
        try {
          await ajax(`/live/rooms/${room.id}`, { type: "DELETE" });
        } catch (e) {
          popupAjaxError(e);
          return;
        }

        // The server already dropped the room, so a server-side leave would
        // only fail; tear down the local call state instead.
        if (this.liveWebrtc.connectionStateFor(room.id) !== "idle") {
          this.liveWebrtc.leave(room, { skipServer: true });
        }
        this.liveRooms.handleDirectoryEvent({ type: "destroyed", room });

        const currentRoute = this.router.currentRoute;
        if (
          currentRoute?.name === "live-room" &&
          currentRoute.params?.slug === room.slug
        ) {
          this.router.replaceWith(homepageNavigationDestination());
        }

        this.toasts.success({ data: { message: i18n("live.room.deleted") } });
        this.args.closeModal();
      },
    });
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
        await ajax(`/live/rooms/${this.room.id}/memberships`, {
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
      await ajax(`/live/rooms/${this.room.id}/memberships/${membership.id}`, {
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
      await ajax(`/live/rooms/${this.room.id}/memberships/${membership.id}`, {
        type: "DELETE",
      });
      await this.loadMemberships();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      class="live-room-info-modal"
      @closeModal={{@closeModal}}
      @title={{if this.isEditing (i18n "live.room.edit")}}
    >
      <:body>
        {{#if this.isEditing}}
          <div class="live-room-info-modal__edit-form">
            <LiveRoomForm
              @onManageMembers={{this.stopEditing}}
              @onSubmit={{this.handleEdit}}
              @room={{this.room}}
            />
            {{#if this.room.can_delete}}
              <DButton
                class="btn-danger live-room-info-modal__delete-btn"
                @action={{this.deleteRoom}}
                @icon="trash-can"
                @label="live.room.delete"
              />
            {{/if}}
          </div>
        {{else}}
          <div class="live-room-info-modal__header">
            <div class="live-room-info-modal__icon">
              {{dIcon (roomIcon this.room)}}
              {{#unless this.room.public}}
                {{dIcon "lock" class="live-room-info-modal__icon-badge"}}
              {{/unless}}
            </div>
            <div class="live-room-info-modal__header-content">
              <h2
                class="live-room-info-modal__room-name"
              >{{this.room.name}}</h2>
              {{#if this.room.cooked_description}}
                <div
                  class="live-room-info-modal__description cooked"
                >{{trustHTML this.room.cooked_description}}</div>
              {{/if}}
            </div>
            {{#if this.room.can_manage}}
              <DButton
                class="btn-flat live-room-info-modal__edit-btn"
                @action={{this.startEditing}}
                @icon="pencil"
                @title="live.room.edit"
              />
            {{/if}}
          </div>

          <div class="live-room-info-modal__stats">
            <div class="live-room-info-modal__stat">
              <span class="live-room-info-modal__stat-value">
                {{#if this.room.public}}
                  {{dIcon "globe"}}
                {{else}}
                  {{dIcon "lock"}}
                {{/if}}
              </span>
              <span class="live-room-info-modal__stat-label">
                {{if
                  this.room.public
                  (i18n "live.room_info.public")
                  (i18n "live.room_info.private")
                }}
              </span>
            </div>

            <div class="live-room-info-modal__stat">
              <span
                class="live-room-info-modal__stat-value"
              >{{this.room.member_count}}</span>
              <span class="live-room-info-modal__stat-label">{{i18n
                  "live.room_info.member_count"
                }}</span>
            </div>

            {{#if this.room.max_participants}}
              <div class="live-room-info-modal__stat">
                <span
                  class="live-room-info-modal__stat-value"
                >{{this.room.max_participants}}</span>
                <span class="live-room-info-modal__stat-label">{{i18n
                    "live.room_info.max_participants"
                  }}</span>
              </div>
            {{/if}}
          </div>

          {{#if this.showMembershipManagement}}
            <div class="live-room-info-modal__members">
              <div class="live-room-info-modal__section-header">
                {{dIcon "users"}}
                <h3>{{i18n "live.room_info.members.title"}}</h3>
              </div>

              {{#if this.loading}}
                <div class="live-room-info-modal__loading">
                  <div class="spinner small"></div>
                  {{i18n "loading"}}
                </div>
              {{else}}
                <div class="live-room-info-modal__member-list">
                  {{#each this.memberships as |membership|}}
                    <div
                      class="live-room-info-modal__member
                        {{if
                          (eq membership.user_id this.room.creator_id)
                          '--creator'
                        }}"
                    >
                      <div class="live-room-info-modal__member-avatar">
                        {{dAvatar membership.user imageSize="medium"}}
                      </div>
                      <div class="live-room-info-modal__member-details">
                        <span
                          class="live-room-info-modal__member-username"
                        >{{membership.user.username}}</span>
                        {{#if (eq membership.user_id this.room.creator_id)}}
                          <span
                            class="live-room-info-modal__member-role --creator"
                          >
                            {{dIcon "crown"}}
                            {{i18n "live.room_info.members.creator"}}
                          </span>
                        {{else}}
                          <span
                            class="live-room-info-modal__member-role --{{membership.role_name}}"
                          >
                            {{membership.role_name}}
                          </span>
                        {{/if}}
                      </div>

                      {{#if (neq membership.user_id this.room.creator_id)}}
                        <div class="live-room-info-modal__member-actions">
                          <ComboBox
                            class="live-room-info-modal__role-select"
                            @content={{this.roleOptions}}
                            @onChange={{fn this.updateMemberRole membership}}
                            @options={{hash none=false}}
                            @value={{membership.role_name}}
                          />
                          <DButton
                            class="btn-flat btn-small live-room-info-modal__remove-btn"
                            @action={{fn this.removeMember membership}}
                            @icon="xmark"
                            @title="live.room_info.members.remove"
                          />
                        </div>
                      {{/if}}
                    </div>
                  {{/each}}
                </div>

                <div class="live-room-info-modal__add-member">
                  <div class="live-room-info-modal__add-row">
                    <UserChooser
                      class="live-room-info-modal__user-chooser"
                      @onChange={{this.setSelectedUsernames}}
                      @options={{hash
                        excludeCurrentUser=false
                        filterPlaceholder="live.room_info.members.add_placeholder"
                      }}
                      @value={{this.selectedUsernames}}
                    />
                    <ComboBox
                      class="live-room-info-modal__role-chooser"
                      @content={{this.roleOptions}}
                      @onChange={{this.setSelectedRole}}
                      @options={{hash none=false}}
                      @value={{this.selectedRole}}
                    />
                    <DButton
                      class="btn-primary live-room-info-modal__add-btn"
                      @action={{this.addMember}}
                      @disabled={{this.addingMember}}
                      @icon="plus"
                      @title="live.room_info.members.add_button"
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
