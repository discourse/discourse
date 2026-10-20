import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import BulkGroupMemberDropdown from "discourse/components/bulk-group-member-dropdown";
import GroupMemberDropdown from "discourse/components/group-member-dropdown";
import PluginOutlet from "discourse/components/plugin-outlet";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DResponsiveTable from "discourse/ui-kit/d-responsive-table";
import DTableHeaderToggle from "discourse/ui-kit/d-table-header-toggle";
import DTextField from "discourse/ui-kit/d-text-field";
import DUserInfo from "discourse/ui-kit/d-user-info";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if (or @controller.loading @controller.canLoadMore)}}
    {{hideApplicationFooter}}
  {{/if}}

  <section class="user-content">
    <div class="group-members-actions">
      {{#if @controller.canManageGroup}}
        <DButton
          class="btn-default bulk-select"
          @action={{@controller.toggleBulkSelect}}
          @icon="list"
          @title="topics.bulk.toggle"
        />
      {{/if}}

      {{#if @controller.model.can_see_members}}
        <DTextField
          class="group-username-filter no-blur"
          @autocomplete="off"
          @placeholderKey={{@controller.filterPlaceholder}}
          @value={{@controller.filterInput}}
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
                class="bulk-select-clear"
                @action={{@controller.bulkClearAll}}
                @icon="far-square"
                @label="topics.bulk.clear_all"
              />
            {{/if}}

            <DButton
              class="bulk-select-all"
              @action={{@controller.bulkSelectAll}}
              @icon="square-check"
              @label="topics.bulk.select_all"
            />
          </span>
        {{/if}}

        <div class="group-members-manage">
          <DButton
            class="btn-default group-members-add"
            @action={{routeAction "showAddMembersModal"}}
            @icon="plus"
            @label="groups.manage.add_members"
          />

          {{#if @controller.currentUser.can_invite_to_forum}}
            <DButton
              class="btn-default group-members-invite"
              @action={{routeAction "showInviteModal"}}
              @icon="plus"
              @label="groups.manage.invite_members"
            />
          {{/if}}
        </div>
      {{/if}}
    </div>

    {{#if @controller.hasMembers}}
      <DLoadMore @action={{@controller.loadMore}}>
        <DResponsiveTable
          @className="group-members
          {{if @controller.isBulk 'sticky-header' ''}}
            {{if @controller.canManageGroup 'group-members--can-manage' ''}}"
        >
          <:header>
            <DTableHeaderToggle
              class="directory-table__column-header--username username"
              @asc={{@controller.asc}}
              @automatic={{true}}
              @colspan="2"
              @field="username_lower"
              @labelKey="username"
              @onToggle={{@controller.updateOrder}}
              @order={{@controller.order}}
            />

            <div
              class="directory-table__column-header directory-table__column-header--can-manage"
            ></div>

            <PluginOutlet
              @name="group-index-table-header-after-username"
              @outletArgs={{lazyHash
                group=@controller.model
                asc=@controller.asc
                order=@controller.order
              }}
            />

            <DTableHeaderToggle
              class="directory-table__column-header--added"
              @asc={{@controller.asc}}
              @automatic={{true}}
              @field="added_at"
              @labelKey="groups.member_added"
              @onToggle={{@controller.updateOrder}}
              @order={{@controller.order}}
            />
            <DTableHeaderToggle
              class="directory-table__column-header--last-posted"
              @asc={{@controller.asc}}
              @automatic={{true}}
              @field="last_posted_at"
              @labelKey="last_post"
              @onToggle={{@controller.updateOrder}}
              @order={{@controller.order}}
            />
            <DTableHeaderToggle
              class="directory-table__column-header--last-seen"
              @asc={{@controller.asc}}
              @automatic={{true}}
              @field="last_seen_at"
              @labelKey="last_seen"
              @onToggle={{@controller.updateOrder}}
              @order={{@controller.order}}
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
                        class="bulk-select"
                        @type="checkbox"
                        {{on "click" (fn @controller.selectMember m)}}
                      />
                    {{/if}}
                  {{/if}}
                  <DUserInfo
                    @showStatus={{true}}
                    @showStatusTooltip={{true}}
                    @skipName={{@controller.skipName}}
                    @user={{m}}
                  />
                </div>

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
                      {{dIcon "shield-halved"}}
                      {{i18n "groups.members.owner"}}<br />
                    {{/if}}
                    {{#if m.primary}}
                      {{i18n "groups.members.primary"}}
                    {{/if}}
                  </span>

                </div>

                <PluginOutlet
                  @name="group-index-table-row-after-username"
                  @outletArgs={{lazyHash member=m}}
                />

                <div class="directory-table__cell directory-table__cell--added">
                  <span class="directory-table__label">
                    <span>{{i18n "groups.member_added"}}</span>
                  </span>
                  <span class="directory-table__value">
                    {{dAgeWithTooltip m.added_at format="medium"}}
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
                    {{dAgeWithTooltip m.last_posted_at format="medium"}}
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
                    {{dAgeWithTooltip m.last_seen_at format="medium"}}
                  </span>
                </div>
                {{#if @controller.canManageGroup}}
                  <div
                    class="directory-table__cell directory-table__cell--member-settings member-settings"
                  >
                    <GroupMemberDropdown
                      @canAdminGroup={{@controller.model.can_admin_group}}
                      @canEditGroup={{@controller.model.can_edit_group}}
                      @member={{m}}
                      @onChange={{fn @controller.actOnGroup m}}
                    />
                    {{! group parameter is used by plugins }}
                  </div>
                {{/if}}
              </div>
            {{/each}}
          </:body>
        </DResponsiveTable>
      </DLoadMore>

      <DConditionalLoadingSpinner @condition={{@controller.loading}} />
    {{else}}
      <br />
      <div>{{i18n @controller.emptyMessageKey}}</div>
    {{/if}}
  </section>
</template>
