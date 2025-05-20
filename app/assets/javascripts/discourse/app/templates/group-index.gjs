import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import { or } from "truth-helpers";
import BulkGroupMemberDropdown from "discourse/components/bulk-group-member-dropdown";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import GroupMemberDropdown from "discourse/components/group-member-dropdown";
import LoadMore from "discourse/components/load-more";
import PluginOutlet from "discourse/components/plugin-outlet";
import ResponsiveTable from "discourse/components/responsive-table";
import TableHeaderToggle from "discourse/components/table-header-toggle";
import TextField from "discourse/components/text-field";
import UserInfo from "discourse/components/user-info";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import icon from "discourse/helpers/d-icon";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{#if (or @controller.loading @controller.canLoadMore)}}
      {{hideApplicationFooter}}
    {{/if}}

    <section class="user-content">
      <div class="group-members-actions">
        {{#if @controller.canManageGroup}}
          <DButton
            @icon="list"
            @action={{@controller.toggleBulkSelect}}
            @title="topics.bulk.toggle"
            class="btn-default bulk-select"
          />
        {{/if}}

        {{#if @controller.model.can_see_members}}
          <TextField
            @value={{@controller.filterInput}}
            @placeholderKey={{@controller.filterPlaceholder}}
            @autocomplete="off"
            class="group-username-filter no-blur"
          />
        {{/if}}

        {{#if @controller.canManageGroup}}
          {{#if @controller.isBulk}}
            <span class="bulk-select-buttons-wrap">
              {{#if @controller.bulkSelection}}
                <BulkGroupMemberDropdown
                  @bulkSelection={{@controller.bulkSelection}}
                  @canAdminGroup={{@controller.model.can_admin_group}}
                  @canEditGroup={{@controller.model.can_edit_group}}
                  @onChange={{fn
                    @controller.actOnSelection
                    @controller.bulkSelection
                  }}
                />

                <DButton
                  @action={{@controller.bulkClearAll}}
                  @label="topics.bulk.clear_all"
                  @icon="far-square"
                  class="bulk-select-clear"
                />
              {{/if}}

              <DButton
                @action={{@controller.bulkSelectAll}}
                @label="topics.bulk.select_all"
                @icon="square-check"
                class="bulk-select-all"
              />
            </span>
          {{/if}}

          <div class="group-members-manage">
            <DButton
              @icon="plus"
              @action={{routeAction "showAddMembersModal"}}
              @label="groups.manage.add_members"
              class="btn-default group-members-add"
            />

            {{#if @controller.currentUser.can_invite_to_forum}}
              <DButton
                @icon="plus"
                @action={{routeAction "showInviteModal"}}
                @label="groups.manage.invite_members"
                class="btn-default group-members-invite"
              />
            {{/if}}
          </div>
        {{/if}}
      </div>

      {{#if @controller.hasMembers}}
        <LoadMore @action={{@controller.loadMore}}>
          <ResponsiveTable
            @className="group-members
          {{if @controller.isBulk 'sticky-header' ''}}
            {{if @controller.canManageGroup 'group-members--can-manage' ''}}"
          >
            <:header>
              <TableHeaderToggle
                @onToggle={{@controller.updateOrder}}
                @order={{@controller.order}}
                @asc={{@controller.asc}}
                @field="username_lower"
                @labelKey="username"
                @automatic={{true}}
                @colspan="2"
                class="directory-table__column-header--username username"
              />

              {{#if @controller.canManageGroup}}
                <div
                  class="directory-table__column-header directory-table__column-header--can-manage"
                ></div>
              {{/if}}

              <PluginOutlet
                @name="group-index-table-header-after-username"
                @outletArgs={{lazyHash
                  group=@controller.model
                  asc=@controller.asc
                  order=@controller.order
                }}
              />

              <TableHeaderToggle
                @onToggle={{@controller.updateOrder}}
                @order={{@controller.order}}
                @asc={{@controller.asc}}
                @field="added_at"
                @labelKey="groups.member_added"
                @automatic={{true}}
                class="directory-table__column-header--added"
              />
              <TableHeaderToggle
                @onToggle={{@controller.updateOrder}}
                @order={{@controller.order}}
                @asc={{@controller.asc}}
                @field="last_posted_at"
                @labelKey="last_post"
                @automatic={{true}}
                class="directory-table__column-header--last-posted"
              />
              <TableHeaderToggle
                @onToggle={{@controller.updateOrder}}
                @order={{@controller.order}}
                @asc={{@controller.asc}}
                @field="last_seen_at"
                @labelKey="last_seen"
                @automatic={{true}}
                class="directory-table__column-header--last-seen"
              />

              {{#if @controller.canManageGroup}}
                <div
                  class="directory-table__column-header directory-table__column-header--member-settings"
                ></div>
              {{/if}}
            </:header>

            <:body>
              {{#each @controller.model.members as |m|}}
                <div class="directory-table__row">
                  <div
                    class="directory-table__cell directory-table__cell--username group-member"
                    colspan="2"
                  >
                    {{#if @controller.canManageGroup}}
                      {{#if @controller.isBulk}}
                        <Input
                          @type="checkbox"
                          class="bulk-select"
                          {{on "click" (fn @controller.selectMember m)}}
                        />
                      {{/if}}
                    {{/if}}
                    <UserInfo
                      @user={{m}}
                      @skipName={{@controller.skipName}}
                      @showStatus={{true}}
                      @showStatusTooltip={{true}}
                    />
                  </div>

                  {{#if @controller.canManageGroup}}
                    <div
                      class="directory-table__cell directory-table__cell--can-manage group-owner"
                    >
                      {{#if (or m.owner m.primary)}}
                        <span class="directory-table__label">
                          <span>{{i18n "groups.members.status"}}</span>
                        </span>
                      {{/if}}
                      <span class="directory-table__value">
                        {{#if m.owner}}
                          {{icon "shield-halved"}}
                          {{i18n "groups.members.owner"}}<br />
                        {{/if}}
                        {{#if m.primary}}
                          {{i18n "groups.members.primary"}}
                        {{/if}}
                      </span>

                    </div>
                  {{/if}}

                  <PluginOutlet
                    @name="group-index-table-row-after-username"
                    @outletArgs={{lazyHash member=m}}
                  />

                  <div
                    class="directory-table__cell directory-table__cell--added"
                  >
                    <span class="directory-table__label">
                      <span>{{i18n "groups.member_added"}}</span>
                    </span>
                    <span class="directory-table__value">
                      {{ageWithTooltip m.added_at format="medium"}}
                    </span>
                  </div>
                  <div
                    class="directory-table__cell{{unless
                        m.last_posted_at
                        '--empty'
                      }}
                      directory-table__cell--last-posted"
                  >
                    {{#if m.last_posted_at}}
                      <span class="directory-table__label">
                        <span>{{i18n "last_post"}}</span>
                      </span>
                    {{/if}}
                    <span class="directory-table__value">
                      {{ageWithTooltip m.last_posted_at format="medium"}}
                    </span>
                  </div>
                  <div
                    class="directory-table__cell{{unless
                        m.last_seen_at
                        '--empty'
                      }}
                      directory-table__cell--last-seen"
                  >
                    {{#if m.last_seen_at}}
                      <span class="directory-table__label">
                        <span>{{i18n "last_seen"}}</span>
                      </span>
                    {{/if}}
                    <span class="directory-table__value">
                      {{ageWithTooltip m.last_seen_at format="medium"}}
                    </span>
                  </div>
                  {{#if @controller.canManageGroup}}
                    <div
                      class="directory-table__cell directory-table__cell--member-settings member-settings"
                    >
                      <GroupMemberDropdown
                        @member={{m}}
                        @canAdminGroup={{@controller.model.can_admin_group}}
                        @canEditGroup={{@controller.model.can_edit_group}}
                        @onChange={{fn @controller.actOnGroup m}}
                      />
                      {{! group parameter is used by plugins }}
                    </div>
                  {{/if}}
                </div>
              {{/each}}
            </:body>
          </ResponsiveTable>
        </LoadMore>

        <ConditionalLoadingSpinner @condition={{@controller.loading}} />
      {{else}}
        <br />
        <div>{{i18n @controller.emptyMessageKey}}</div>
      {{/if}}
    </section>
  </template>
);
