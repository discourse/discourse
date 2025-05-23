import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import { eq, not, or } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import DropdownMenu from "discourse/components/dropdown-menu";
import LoadMore from "discourse/components/load-more";
import PluginOutlet from "discourse/components/plugin-outlet";
import ResponsiveTable from "discourse/components/responsive-table";
import TableHeaderToggle from "discourse/components/table-header-toggle";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import formatDuration from "discourse/helpers/format-duration";
import htmlSafe from "discourse/helpers/html-safe";
import i18nYesNo from "discourse/helpers/i18n-yes-no";
import lazyHash from "discourse/helpers/lazy-hash";
import number from "discourse/helpers/number";
import rawDate from "discourse/helpers/raw-date";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";
import DTooltip from "float-kit/components/d-tooltip";

export default RouteTemplate(
  <template>
    <DPageSubheader @titleLabel={{@controller.title}}>
      <:actions as |actions|>
        {{#if @controller.canCheckEmails}}
          {{#if @controller.showEmails}}
            <actions.Default
              @action={{@controller.toggleEmailVisibility}}
              @label="admin.users.hide_emails"
              class="admin-users__subheader-hide-emails"
            />
          {{else}}
            <actions.Default
              @action={{@controller.toggleEmailVisibility}}
              @label="admin.users.show_emails"
              class="admin-users__subheader-show-emails"
            />
          {{/if}}
        {{/if}}
      </:actions>
    </DPageSubheader>

    <PluginOutlet @name="admin-users-list-show-before" />

    <div class="d-admin-filter admin-users-list__controls">
      <div class="admin-filter__input-container admin-users-list__search">
        <input
          class="admin-filter__input"
          type="text"
          dir="auto"
          placeholder={{@controller.searchHint}}
          title={{@controller.searchHint}}
          {{on "input" @controller.onListFilterChange}}
        />
      </div>
      {{#if @controller.displayBulkActions}}
        <div class="bulk-actions-dropdown">
          <DMenu
            @autofocus={{true}}
            @identifier="bulk-select-admin-users-dropdown"
          >
            <:trigger>
              <span class="d-button-label">
                {{i18n "admin.users.bulk_actions.title"}}
              </span>
              {{icon "angle-down"}}
            </:trigger>

            <:content>
              <DropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    @translatedLabel={{i18n
                      "admin.users.bulk_actions.delete.label"
                    }}
                    @icon="trash-can"
                    @action={{@controller.openBulkDeleteConfirmation}}
                    class="bulk-delete btn-danger"
                  />
                </dropdown.item>
              </DropdownMenu>
            </:content>
          </DMenu>
        </div>
      {{/if}}
    </div>
    <LoadMore @action={{@controller.loadMore}} class="users-list-container">
      {{#if @controller.users}}
        <ResponsiveTable
          @className={{concatClass "users-list" @controller.query}}
          @ariaLabel={{@controller.title}}
          @style={{htmlSafe
            (concat
              "grid-template-columns: minmax(min-content, 2fr) repeat("
              (htmlSafe @controller.columnCount)
              ", minmax(min-content, 1fr))"
            )
          }}
        >
          <:header>
            <div class="directory-table__column-header-wrapper">
              <DButton
                class="btn-flat bulk-select"
                @icon="list-check"
                @action={{@controller.toggleBulkSelect}}
              />
              <TableHeaderToggle
                @onToggle={{@controller.updateOrder}}
                @field="username"
                @labelKey="username"
                @order={{@controller.order}}
                @asc={{@controller.asc}}
                @automatic={{true}}
                class="directory-table__column-header--username"
              />
            </div>
            <TableHeaderToggle
              @onToggle={{@controller.updateOrder}}
              @field="email"
              @labelKey="email"
              @order={{@controller.order}}
              @asc={{@controller.asc}}
              @automatic={{true}}
              class={{if
                @controller.showEmails
                "directory-table__column-header--email"
                "hidden"
              }}
            />
            <TableHeaderToggle
              @onToggle={{@controller.updateOrder}}
              @field="last_emailed"
              @labelKey="admin.users.last_emailed"
              @order={{@controller.order}}
              @asc={{@controller.asc}}
              @automatic={{true}}
            />
            <TableHeaderToggle
              @onToggle={{@controller.updateOrder}}
              @field="seen"
              @labelKey="last_seen"
              @order={{@controller.order}}
              @asc={{@controller.asc}}
              @automatic={{true}}
            />
            {{#unless @controller.showSilenceReason}}
              <TableHeaderToggle
                @onToggle={{@controller.updateOrder}}
                @field="topics_viewed"
                @labelKey="admin.user.topics_entered"
                @order={{@controller.order}}
                @asc={{@controller.asc}}
                @automatic={{true}}
              />
            {{/unless}}
            <TableHeaderToggle
              @onToggle={{@controller.updateOrder}}
              @field="posts_read"
              @labelKey="admin.user.posts_read_count"
              @order={{@controller.order}}
              @asc={{@controller.asc}}
              @automatic={{true}}
            />
            <TableHeaderToggle
              @onToggle={{@controller.updateOrder}}
              @field="read_time"
              @labelKey="admin.user.time_read"
              @order={{@controller.order}}
              @asc={{@controller.asc}}
              @automatic={{true}}
            />
            <TableHeaderToggle
              @onToggle={{@controller.updateOrder}}
              @field="created"
              @labelKey="created"
              @order={{@controller.order}}
              @asc={{@controller.asc}}
              @automatic={{true}}
            />
            {{#if @controller.showSilenceReason}}
              <TableHeaderToggle
                @onToggle={{@controller.updateOrder}}
                @field="silence_reason"
                @labelKey="admin.users.silence_reason"
                @order={{@controller.order}}
                @asc={{@controller.asc}}
                @automatic={{true}}
                class="directory-table__column-header--silence-reason"
              />
            {{/if}}
            <PluginOutlet
              @name="admin-users-list-thead-after"
              @outletArgs={{lazyHash
                order=@controller.order
                asc=@controller.asc
              }}
            />

            {{#if @controller.siteSettings.must_approve_users}}
              <div class="directory-table__column-header">{{i18n
                  "admin.users.approved"
                }}</div>
            {{/if}}
            <div class="directory-table__column-header">&nbsp;</div>

          </:header>

          <:body>
            {{#each @controller.users as |user|}}
              <div
                class="user
                  {{user.selected}}
                  {{unless user.active 'not-activated'}}
                  directory-table__row"
                data-user-id={{user.id}}
              >
                <div class="directory-table__cell username">
                  {{#if @controller.bulkSelect}}
                    {{#if user.can_be_deleted}}
                      <input
                        type="checkbox"
                        class="directory-table__cell-bulk-select"
                        checked={{eq
                          (get @controller.bulkSelectedUsersMap user.id)
                          1
                        }}
                        data-user-id={{user.id}}
                        {{on
                          "click"
                          (fn @controller.bulkSelectItemToggle user.id)
                        }}
                      />
                    {{else}}
                      <DTooltip
                        @identifier="bulk-delete-unavailable-reason"
                        @placement="bottom-start"
                      >
                        <:trigger>
                          <input
                            type="checkbox"
                            class="directory-table__cell-bulk-select"
                            disabled={{true}}
                          />
                        </:trigger>
                        <:content>
                          {{#if user.admin}}
                            {{i18n
                              "admin.users.bulk_actions.admin_cant_be_deleted"
                            }}
                          {{else}}
                            {{i18n
                              "admin.users.bulk_actions.too_many_or_old_posts"
                            }}
                          {{/if}}
                        </:content>
                      </DTooltip>
                    {{/if}}
                  {{/if}}
                  <a
                    class="avatar"
                    href={{user.path}}
                    data-user-card={{user.username}}
                  >
                    {{avatar user imageSize="small"}}
                  </a>
                  <LinkTo @route="adminUser" @model={{user}}>
                    {{user.username}}
                  </LinkTo>
                  {{#if user.staged}}
                    {{icon "far-envelope" title="user.staged"}}
                  {{/if}}
                </div>
                <div
                  class="directory-table__cell email
                    {{if @controller.showEmails '' 'hidden'}}"
                >
                  <span class="directory-table__value">
                    {{~user.email~}}
                  </span>
                </div>

                {{#if user.last_emailed_at}}
                  <div
                    class="directory-table__cell last-emailed"
                    title={{rawDate user.last_emailed_at}}
                  >
                    <span class="directory-table__label">
                      <span>{{i18n "admin.users.last_emailed"}}</span>
                    </span>
                    <span class="directory-table__value">
                      {{formatDuration user.last_emailed_age}}
                    </span>
                  </div>
                {{else}}
                  <div class="directory-table__cell last-emailed">
                    <span class="directory-table__label">
                      <span>{{i18n "admin.users.last_emailed"}}</span>
                    </span>
                    <span class="directory-table__value">
                      {{formatDuration user.last_emailed_age}}
                    </span>
                  </div>
                {{/if}}

                <div
                  class="directory-table__cell last-seen"
                  title={{rawDate user.last_seen_at}}
                >
                  <span class="directory-table__label">
                    <span>{{i18n "last_seen"}}</span>
                  </span>
                  <span class="directory-table__value">
                    {{formatDuration user.last_seen_age}}
                  </span>
                </div>

                {{#unless @controller.showSilenceReason}}
                  <div class="directory-table__cell topics-entered">
                    <span class="directory-table__label">
                      <span>{{i18n "admin.user.topics_entered"}}</span>
                    </span>
                    <span class="directory-table__value">
                      {{number user.topics_entered}}
                    </span>
                  </div>
                {{/unless}}
                <div class="directory-table__cell posts-read">
                  <span class="directory-table__label">
                    <span>{{i18n "admin.user.posts_read_count"}}</span>
                  </span>
                  <span class="directory-table__value">
                    {{number user.posts_read_count}}
                  </span>
                </div>
                <div class="directory-table__cell time-read">
                  <span class="directory-table__label">
                    <span>{{i18n "admin.user.time_read"}}</span>
                  </span>
                  <span class="directory-table__value">
                    {{formatDuration user.time_read}}
                  </span>
                </div>
                <div
                  class="directory-table__cell created"
                  title={{rawDate user.created_at}}
                >
                  <span class="directory-table__label">
                    <span>{{i18n "created"}}</span>
                  </span>
                  <span class="directory-table__value">
                    {{formatDuration user.created_at_age}}
                  </span>
                </div>

                {{#if @controller.showSilenceReason}}
                  <div
                    class="directory-table__cell silence_reason"
                    title={{@controller.stripHtml user.silence_reason}}
                  >
                    <span class="directory-table__label">
                      <span>{{i18n "admin.users.silence_reason"}}</span>
                    </span>
                    <span class="directory-table__value">
                      {{htmlSafe user.silence_reason}}
                    </span>
                  </div>
                {{/if}}

                <PluginOutlet
                  @name="admin-users-list-td-after"
                  @outletArgs={{lazyHash user=user query=@controller.query}}
                />

                {{#if @controller.siteSettings.must_approve_users}}
                  <div class="directory-table__cell">
                    <span class="directory-table__label">
                      <span>{{i18n "admin.users.approved"}}</span>
                    </span>
                    <span class="directory-table__value">
                      {{i18nYesNo user.approved}}
                    </span>
                  </div>
                {{/if}}

                <div
                  class={{concatClass
                    "directory-table__cell"
                    "user-role"
                    (if
                      (not
                        (or
                          user.admin user.moderator user.second_factor_enabled
                        )
                      )
                      "--empty"
                    )
                  }}
                >
                  <span class="directory-table__label">
                    <span>{{i18n "admin.users.status"}}</span>
                  </span>
                  <span class="directory-table__value">
                    {{#if user.admin}}
                      {{icon "shield-halved" title="admin.title"}}
                    {{/if}}
                    {{#if user.moderator}}
                      {{icon "shield-halved" title="admin.moderator"}}
                    {{/if}}
                    {{#if user.second_factor_enabled}}
                      {{icon "lock" title="admin.user.second_factor_enabled"}}
                    {{/if}}
                  </span>
                  <PluginOutlet
                    @name="admin-users-list-icon"
                    @connectorTagName="div"
                    @outletArgs={{lazyHash user=user query=@controller.query}}
                  />
                </div>
              </div>
            {{/each}}
          </:body>
        </ResponsiveTable>
      {{else if (not @controller.refreshing)}}
        <p>{{i18n "search.no_results"}}</p>
      {{/if}}
      <ConditionalLoadingSpinner @condition={{@controller.refreshing}} />
    </LoadMore>
  </template>
);
