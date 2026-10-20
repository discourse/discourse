import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { escapeExpression } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

export default class LiveRoomList extends Component {
  @service dialog;

  @action
  async endCall(room) {
    await this.dialog.yesNoConfirm({
      message: i18n("live.admin.end_call.confirm", {
        name: escapeExpression(room.name),
      }),
      didConfirm: async () => {
        try {
          await ajax(`/admin/plugins/live/rooms/${room.id}/end_call`, {
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
  async destroyRoom(room, closeMenu) {
    await closeMenu();

    await this.dialog.deleteConfirm({
      message: i18n("live.admin.destroy_room.confirm", {
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
  }

  <template>
    <section class="live-rooms-table">
      <DPageSubheader @titleLabel={{i18n "live.admin.rooms_title"}}>
        <:actions as |actions|>
          <actions.Primary
            class="live-admin__create-btn"
            @icon="plus"
            @label="live.admin.create_room"
            @route="adminPlugins.show.live-rooms.new"
          />
        </:actions>
      </DPageSubheader>

      {{#if @rooms.length}}
        <table class="d-table live-rooms">
          <thead class="d-table__header">
            <tr>
              <th class="d-table__header-cell">{{i18n
                  "live.admin.room.name"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "live.admin.room.creator"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "live.admin.room.public"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "live.admin.room.max_participants"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "live.admin.room.member_count"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "live.admin.room.created_at"
                }}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each @rooms as |room|}}
              <tr class="d-table__row">
                <td class="d-table__cell --overview live-rooms__name">
                  <LinkTo
                    class="d-table__overview-link live-rooms__name-link"
                    @model={{room.id}}
                    @route="adminPlugins.show.live-rooms.edit"
                  >
                    <strong
                      class="d-table__overview-name"
                    >{{room.name}}</strong>
                  </LinkTo>
                </td>
                <td class="d-table__cell --detail live-rooms__creator">
                  <div class="d-table__mobile-label">
                    {{i18n "live.admin.room.creator"}}
                  </div>
                  {{#if room.creator}}
                    <DUserLink
                      class="live-rooms__creator-link"
                      @user={{room.creator}}
                    >
                      {{dAvatar room.creator imageSize="tiny"}}
                      <span>{{room.creator.username}}</span>
                    </DUserLink>
                  {{/if}}
                </td>
                <td class="d-table__cell --detail live-rooms__public">
                  <div class="d-table__mobile-label">
                    {{i18n "live.admin.room.public"}}
                  </div>
                  {{#if room.public}}
                    {{i18n "yes_value"}}
                  {{else}}
                    {{i18n "no_value"}}
                  {{/if}}
                </td>
                <td class="d-table__cell --detail live-rooms__max-participants">
                  <div class="d-table__mobile-label">
                    {{i18n "live.admin.room.max_participants"}}
                  </div>
                  {{#if room.max_participants}}
                    {{room.max_participants}}
                  {{else}}
                    -
                  {{/if}}
                </td>
                <td class="d-table__cell --detail live-rooms__member-count">
                  <div class="d-table__mobile-label">
                    {{i18n "live.admin.room.member_count"}}
                  </div>
                  {{room.member_count}}
                </td>
                <td class="d-table__cell --detail live-rooms__created-at">
                  <div class="d-table__mobile-label">
                    {{i18n "live.admin.room.created_at"}}
                  </div>
                  {{dFormatDate room.created_at leaveAgo="true"}}
                </td>
                <td class="d-table__cell --controls live-rooms__controls">
                  {{#if room.live_participant_count}}
                    <DButton
                      class="btn-small btn-danger live-rooms__end-call"
                      @icon="phone-slash"
                      @title="live.admin.end_call.title"
                      {{on "click" (fn this.endCall room)}}
                    />
                  {{/if}}

                  <LinkTo
                    class="btn btn-default btn-text btn-small"
                    @model={{room.id}}
                    @route="adminPlugins.show.live-rooms.edit"
                  >
                    {{i18n "live.admin.edit"}}
                  </LinkTo>

                  <DMenu
                    @icon="ellipsis-vertical"
                    @identifier="live-rooms-menu"
                    @placement="bottom-end"
                    @title={{i18n "more_options"}}
                    @triggerClass="btn-default btn-small"
                  >
                    <:content as |menu|>
                      <DDropdownMenu as |dropdown|>
                        <dropdown.item>
                          <DButton
                            class="btn-transparent --danger live-rooms__delete"
                            @action={{fn this.destroyRoom room menu.close}}
                            @icon="trash-can"
                            @label="delete"
                          />
                        </dropdown.item>
                      </DDropdownMenu>
                    </:content>
                  </DMenu>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <AdminConfigAreaEmptyList
          @ctaClass="live-admin__create-btn"
          @ctaLabel="live.admin.create_room"
          @ctaRoute="adminPlugins.show.live-rooms.new"
          @emptyLabel="live.admin.no_rooms_yet"
        />
      {{/if}}
    </section>
  </template>
}
