import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { escapeExpression } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

export default class VoiceRoomList extends Component {
  @service dialog;

  @action
  async endCall(room) {
    await this.dialog.yesNoConfirm({
      message: i18n("voice.admin.end_call.confirm", {
        name: escapeExpression(room.name),
      }),
      didConfirm: async () => {
        try {
          await ajax(`/admin/plugins/voice/rooms/${room.id}/end_call`, {
            type: "POST",
          });
          room.set("live_participant_count", 0);
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  async destroyRoom(room) {
    room.set("isDeleting", true);
    try {
      await this.dialog.deleteConfirm({
        message: i18n("voice.admin.destroy_room.confirm", {
          name: escapeExpression(room.name),
        }),
        didConfirm: async () => {
          try {
            await room.destroyRecord();
            this.args.onDestroy?.(room);
          } catch (e) {
            popupAjaxError(e);
          }
        },
      });
    } finally {
      room?.set("isDeleting", false);
    }
  }

  <template>
    <section class="voice-rooms-table">
      <DPageSubheader @titleLabel={{i18n "voice.admin.rooms_title"}}>
        <:actions as |actions|>
          <actions.Primary
            @label="voice.admin.create_room"
            @route="adminPlugins.show.voice-rooms.new"
            @icon="plus"
            class="voice-admin__create-btn"
          />
        </:actions>
      </DPageSubheader>

      {{#if @rooms.length}}
        <table class="d-admin-table voice-rooms">
          <thead>
            <tr>
              <th>{{i18n "voice.admin.room.name"}}</th>
              <th>{{i18n "voice.admin.room.public"}}</th>
              <th>{{i18n "voice.admin.room.max_participants"}}</th>
              <th>{{i18n "voice.admin.room.member_count"}}</th>
              <th>{{i18n "voice.admin.room.creator"}}</th>
              <th>{{i18n "voice.admin.room.created_at"}}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each @rooms as |room|}}
              <tr class="d-admin-row__content">
                <td class="d-admin-row__overview voice-rooms__name">
                  {{room.name}}
                </td>
                <td class="d-admin-row__detail voice-rooms__public">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "voice.admin.room.public"}}
                  </div>
                  {{#if room.public}}
                    {{i18n "yes_value"}}
                  {{else}}
                    {{i18n "no_value"}}
                  {{/if}}
                </td>
                <td class="d-admin-row__detail voice-rooms__max-participants">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "voice.admin.room.max_participants"}}
                  </div>
                  {{#if room.max_participants}}
                    {{room.max_participants}}
                  {{else}}
                    -
                  {{/if}}
                </td>
                <td class="d-admin-row__detail voice-rooms__member-count">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "voice.admin.room.member_count"}}
                  </div>
                  {{room.member_count}}
                </td>
                <td class="d-admin-row__detail voice-rooms__creator">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "voice.admin.room.creator"}}
                  </div>
                  {{#if room.creator}}
                    <a
                      href={{room.creator.userPath}}
                      data-user-card={{room.creator.username}}
                    >
                      {{dAvatar room.creator imageSize="small"}}
                    </a>
                  {{/if}}
                </td>
                <td class="d-admin-row__detail voice-rooms__created-at">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "voice.admin.room.created_at"}}
                  </div>
                  {{dFormatDate room.created_at leaveAgo="true"}}
                </td>
                <td class="d-admin-row__controls voice-rooms__controls">
                  {{#if room.live_participant_count}}
                    <DButton
                      @icon="phone-slash"
                      @title="voice.admin.end_call.title"
                      {{on "click" (fn this.endCall room)}}
                      class="btn-small btn-danger voice-rooms__end-call"
                    />
                  {{/if}}

                  <LinkTo
                    @route="adminPlugins.show.voice-rooms.edit"
                    @model={{room.id}}
                    class="btn btn-default btn-text btn-small"
                  >
                    {{i18n "voice.admin.edit"}}
                  </LinkTo>

                  <DButton
                    @icon="trash-can"
                    @disabled={{room.isDeleting}}
                    {{on "click" (fn this.destroyRoom room)}}
                    class="btn-small btn-danger voice-rooms__delete"
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <AdminConfigAreaEmptyList
          @ctaLabel="voice.admin.create_room"
          @ctaRoute="adminPlugins.show.voice-rooms.new"
          @ctaClass="voice-admin__create-btn"
          @emptyLabel="voice.admin.no_rooms_yet"
        />
      {{/if}}
    </section>
  </template>
}
