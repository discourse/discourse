import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import DMenu from "discourse/float-kit/components/d-menu";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import i18nYesNo from "discourse/helpers/i18n-yes-no";
import lazyHash from "discourse/helpers/lazy-hash";
import rawDate from "discourse/helpers/raw-date";
import { not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DResponsiveTable from "discourse/ui-kit/d-responsive-table";
import DTableHeaderToggle from "discourse/ui-kit/d-table-header-toggle";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDuration from "discourse/ui-kit/helpers/d-format-duration";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";

const ACTIVATION_FILTER_OPTIONS = [
  { value: "all", label: i18n("admin.users.activation_filter.all") },
  {
    value: "activated",
    label: i18n("admin.users.activation_filter.activated"),
  },
  {
    value: "not_activated",
    label: i18n("admin.users.activation_filter.not_activated"),
  },
];

export default <template>
  <DPageSubheader @titleLabel={{@controller.title}}>
    <:actions as |actions|>
      {{#if @controller.canCheckEmails}}
        {{#if @controller.showEmails}}
          <actions.Default
            class="admin-users__subheader-hide-emails"
            @action={{@controller.toggleEmailVisibility}}
            @label="admin.users.hide_emails"
          />
        {{else}}
          <actions.Default
            class="admin-users__subheader-show-emails"
            @action={{@controller.toggleEmailVisibility}}
            @label="admin.users.show_emails"
          />
        {{/if}}
      {{/if}}
    </:actions>
  </DPageSubheader>

  <PluginOutlet @name="admin-users-list-show-before" />

  <DFilterControls
    @array={{@controller.users}}
    @dropdownOptions={{if
      @controller.showActivationFilter
      ACTIVATION_FILTER_OPTIONS
    }}
    @dropdownValue={{or @controller.activation "all"}}
    @initialTextFilter={{@controller.initialFilter}}
    @inputPlaceholder={{@controller.searchHint}}
    @loading={{@controller.refreshing}}
    @noResultsMessage={{i18n "search.no_results"}}
    @onDropdownFilterChange={{@controller.onActivationChange}}
    @onResetFilters={{@controller.onResetFilters}}
    @onTextFilterChange={{@controller.onListFilterChange}}
    @textFilterQueryParam="filter"
  >
    <:actions>
      {{#if @controller.displayBulkActions}}
        <div class="bulk-actions-dropdown">
          <DMenu
            @autofocus={{true}}
            @identifier="bulk-select-admin-users-dropdown"
            @triggerClass="btn-default"
          >
            <:trigger>
              <span class="d-button-label">
                {{i18n "admin.users.bulk_actions.title"}}
              </span>
              {{dIcon "angle-down"}}
            </:trigger>

            <:content>
              <DDropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    class="bulk-suspend btn-danger"
                    @action={{@controller.openBulkSuspendConfirmation}}
                    @icon="ban"
                    @translatedLabel={{i18n
                      "admin.users.bulk_actions.suspend.label"
                    }}
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    class="bulk-delete btn-danger"
                    @action={{@controller.openBulkDeleteConfirmation}}
                    @icon="trash-can"
                    @translatedLabel={{i18n
                      "admin.users.bulk_actions.delete.label"
                    }}
                  />
                </dropdown.item>
              </DDropdownMenu>
            </:content>
          </DMenu>
        </div>
      {{/if}}
    </:actions>

    <:aboveContent>
      {{! only spin above the table when there are no rows yet; otherwise the
      pagination spinner lives below the table (see :content) so loading more
      doesn't shove the table down }}
      {{#unless @controller.users.length}}
        <DConditionalLoadingSpinner @condition={{@controller.refreshing}} />
      {{/unless}}

      {{#if @controller.showEmptyState}}
        <p class="admin-users-list__no-results">{{i18n "search.no_results"}}</p>
      {{/if}}
    </:aboveContent>

    <:content as |users|>
      <DLoadMore class="users-list-container" @action={{@controller.loadMore}}>
        <DResponsiveTable
          @ariaLabel={{@controller.title}}
          @className={{dConcatClass "users-list" @controller.query}}
          @style={{trustHTML
            (concat
              "grid-template-columns: minmax(min-content, 2fr) repeat("
              (trustHTML @controller.columnCount)
              ", minmax(min-content, 1fr))"
            )
          }}
        >
          <:header>
            <div class="directory-table__column-header-wrapper">
              <DButton
                class="btn-flat bulk-select"
                @action={{@controller.toggleBulkSelect}}
                @icon="list-check"
              />
              {{#if @controller.bulkSelect}}
                <DButton
                  class="btn-flat bulk-select-all"
                  @action={{@controller.bulkSelectAll}}
                  @label="admin.users.bulk_actions.select_all"
                />
                <DButton
                  class="btn-flat bulk-clear-all"
                  @action={{@controller.bulkClearAll}}
                  @label="admin.users.bulk_actions.clear_all"
                />
              {{/if}}
              <DTableHeaderToggle
                class="directory-table__column-header--username"
                @asc={{@controller.asc}}
                @automatic={{true}}
                @field="username"
                @labelKey="username"
                @onToggle={{@controller.updateOrder}}
                @order={{@controller.order}}
              />
            </div>
            <DTableHeaderToggle
              class={{if
                @controller.showEmails
                "directory-table__column-header--email"
                "hidden"
              }}
              @asc={{@controller.asc}}
              @automatic={{true}}
              @field="email"
              @labelKey="email"
              @onToggle={{@controller.updateOrder}}
              @order={{@controller.order}}
            />
            <DTableHeaderToggle
              @asc={{@controller.asc}}
              @automatic={{true}}
              @field="last_emailed"
              @labelKey="admin.users.last_emailed"
              @onToggle={{@controller.updateOrder}}
              @order={{@controller.order}}
            />
            <DTableHeaderToggle
              @asc={{@controller.asc}}
              @automatic={{true}}
              @field="seen"
              @labelKey="last_seen"
              @onToggle={{@controller.updateOrder}}
              @order={{@controller.order}}
            />
            {{#unless
              (or @controller.showSilenceReason @controller.showSuspendReason)
            }}
              <DTableHeaderToggle
                @asc={{@controller.asc}}
                @automatic={{true}}
                @field="topics_viewed"
                @labelKey="admin.user.topics_entered"
                @onToggle={{@controller.updateOrder}}
                @order={{@controller.order}}
              />
            {{/unless}}
            <DTableHeaderToggle
              @asc={{@controller.asc}}
              @automatic={{true}}
              @field="posts_read"
              @labelKey="admin.user.posts_read_count"
              @onToggle={{@controller.updateOrder}}
              @order={{@controller.order}}
            />
            <DTableHeaderToggle
              @asc={{@controller.asc}}
              @automatic={{true}}
              @field="read_time"
              @labelKey="admin.user.time_read"
              @onToggle={{@controller.updateOrder}}
              @order={{@controller.order}}
            />
            <DTableHeaderToggle
              @asc={{@controller.asc}}
              @automatic={{true}}
              @field="created"
              @labelKey="created"
              @onToggle={{@controller.updateOrder}}
              @order={{@controller.order}}
            />
            {{#if @controller.showSilenceReason}}
              <DTableHeaderToggle
                class="directory-table__column-header--silence-reason"
                @asc={{@controller.asc}}
                @automatic={{true}}
                @field="silence_reason"
                @labelKey="admin.users.silence_reason"
                @onToggle={{@controller.updateOrder}}
                @order={{@controller.order}}
              />
            {{/if}}
            {{#if @controller.showSuspendReason}}
              <DTableHeaderToggle
                class="directory-table__column-header--suspend-reason"
                @asc={{@controller.asc}}
                @automatic={{true}}
                @field="suspend_reason"
                @labelKey="admin.users.suspend_reason"
                @onToggle={{@controller.updateOrder}}
                @order={{@controller.order}}
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
            {{#each users as |user|}}
              <div
                class="user
                  {{user.selected}}
                  {{unless user.active 'not-activated'}}
                  directory-table__row"
                data-user-id={{user.id}}
              >
                <div class="directory-table__cell username">
                  {{#if @controller.bulkSelect}}
                    {{#if (or user.can_be_deleted user.can_be_suspended)}}
                      <input
                        checked={{get @controller.bulkSelectedUsersMap user.id}}
                        class="directory-table__cell-bulk-select"
                        data-user-id={{user.id}}
                        type="checkbox"
                        {{on
                          "click"
                          (fn @controller.bulkSelectItemToggle user.id)
                        }}
                      />
                    {{else}}
                      <DTooltip
                        @identifier="bulk-action-unavailable-reason"
                        @placement="bottom-start"
                      >
                        <:trigger>
                          <input
                            class="directory-table__cell-bulk-select"
                            disabled={{true}}
                            type="checkbox"
                          />
                        </:trigger>
                        <:content>
                          {{i18n
                            "admin.users.bulk_actions.staff_cant_be_actioned"
                          }}
                        </:content>
                      </DTooltip>
                    {{/if}}
                  {{/if}}
                  <a
                    class="avatar"
                    data-user-card={{user.username}}
                    href={{user.path}}
                  >
                    {{dAvatar user imageSize="small"}}
                  </a>
                  <LinkTo @model={{user}} @route="adminUser">
                    {{user.username}}
                  </LinkTo>
                  {{#if user.staged}}
                    {{dIcon "far-envelope" title="user.staged"}}
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
                      {{dFormatDuration user.last_emailed_age}}
                    </span>
                  </div>
                {{else}}
                  <div class="directory-table__cell last-emailed">
                    <span class="directory-table__label">
                      <span>{{i18n "admin.users.last_emailed"}}</span>
                    </span>
                    <span class="directory-table__value">
                      {{dFormatDuration user.last_emailed_age}}
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
                    {{dFormatDuration user.last_seen_age}}
                  </span>
                </div>

                {{#unless
                  (or
                    @controller.showSilenceReason @controller.showSuspendReason
                  )
                }}
                  <div class="directory-table__cell topics-entered">
                    <span class="directory-table__label">
                      <span>{{i18n "admin.user.topics_entered"}}</span>
                    </span>
                    <span class="directory-table__value">
                      {{dNumber user.topics_entered}}
                    </span>
                  </div>
                {{/unless}}
                <div class="directory-table__cell posts-read">
                  <span class="directory-table__label">
                    <span>{{i18n "admin.user.posts_read_count"}}</span>
                  </span>
                  <span class="directory-table__value">
                    {{dNumber user.posts_read_count}}
                  </span>
                </div>
                <div class="directory-table__cell time-read">
                  <span class="directory-table__label">
                    <span>{{i18n "admin.user.time_read"}}</span>
                  </span>
                  <span class="directory-table__value">
                    {{dFormatDuration user.time_read}}
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
                    {{dFormatDuration user.created_at_age}}
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
                      {{trustHTML user.silence_reason}}
                    </span>
                  </div>
                {{/if}}

                {{#if @controller.showSuspendReason}}
                  <div
                    class="directory-table__cell suspend_reason"
                    title={{@controller.stripHtml user.suspend_reason}}
                  >
                    <span class="directory-table__label">
                      <span>{{i18n "admin.users.suspend_reason"}}</span>
                    </span>
                    <span class="directory-table__value">
                      {{trustHTML user.suspend_reason}}
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
                  class={{dConcatClass
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
                      {{dIcon "shield-halved" title="admin.title"}}
                    {{/if}}
                    {{#if user.moderator}}
                      {{dIcon "shield-halved" title="admin.moderator"}}
                    {{/if}}
                    {{#if user.second_factor_enabled}}
                      {{dIcon "lock" title="admin.user.second_factor_enabled"}}
                    {{/if}}
                  </span>
                  <PluginOutlet
                    @connectorTagName="div"
                    @name="admin-users-list-icon"
                    @outletArgs={{lazyHash user=user query=@controller.query}}
                  />
                </div>
              </div>
            {{/each}}
          </:body>
        </DResponsiveTable>

        <DConditionalLoadingSpinner @condition={{@controller.refreshing}} />
      </DLoadMore>
    </:content>
  </DFilterControls>
</template>
