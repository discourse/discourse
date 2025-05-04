import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";
import StaffActions from "admin/components/staff-actions";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    <div class="staff-action-logs-controls">
      {{#if @controller.filtersExists}}
        <div class="staff-action-logs-filters">
          <a
            href
            {{on "click" @controller.clearAllFilters}}
            class="clear-filters filter btn"
          >
            <span class="label">{{i18n
                "admin.logs.staff_actions.clear_filters"
              }}</span>
          </a>
          {{#if @controller.actionFilter}}
            <a
              href
              {{on "click" (fn @controller.clearFilter "actionFilter")}}
              class="filter btn"
            >
              <span class="label">{{i18n "admin.logs.action"}}</span>:
              {{@controller.actionFilter}}
              {{icon "circle-xmark"}}
            </a>
          {{/if}}
          {{#if @controller.filters.acting_user}}
            <a
              href
              {{on "click" (fn @controller.clearFilter "acting_user")}}
              class="filter btn"
            >
              <span class="label">{{i18n
                  "admin.logs.staff_actions.staff_user"
                }}</span>:
              {{@controller.filters.acting_user}}
              {{icon "circle-xmark"}}
            </a>
          {{/if}}
          {{#if @controller.filters.target_user}}
            <a
              href
              {{on "click" (fn @controller.clearFilter "target_user")}}
              class="filter btn"
            >
              <span class="label">{{i18n
                  "admin.logs.staff_actions.target_user"
                }}</span>:
              {{@controller.filters.target_user}}
              {{icon "circle-xmark"}}
            </a>
          {{/if}}
          {{#if @controller.filters.subject}}
            <a
              href
              {{on "click" (fn @controller.clearFilter "subject")}}
              class="filter btn"
            >
              <span class="label">{{i18n
                  "admin.logs.staff_actions.subject"
                }}</span>:
              {{@controller.filters.subject}}
              {{icon "circle-xmark"}}
            </a>
          {{/if}}
        </div>
      {{else}}
        {{i18n "admin.logs.staff_actions.filter"}}
        <ComboBox
          @content={{@controller.userHistoryActions}}
          @value={{@controller.filterActionId}}
          @onChange={{@controller.filterActionIdChanged}}
          @options={{hash none="admin.logs.staff_actions.all"}}
          @id="staff-action-logs-action-filter"
        />
      {{/if}}

      <DButton
        @action={{@controller.exportStaffActionLogs}}
        @label="admin.export_csv.button_text"
        @icon="download"
        class="btn-default"
      />
    </div>

    <div class="clearfix"></div>

    <StaffActions>
      <LoadMore @action={{@controller.loadMore}}>
        {{#if @controller.model.content}}
          <table class="table staff-logs grid">
            <thead>
              <th>{{i18n "admin.logs.staff_actions.staff_user"}}</th>
              <th>{{i18n "admin.logs.action"}}</th>
              <th>{{i18n "admin.logs.staff_actions.subject"}}</th>
              <th>{{i18n "admin.logs.staff_actions.when"}}</th>
              <th>{{i18n "admin.logs.staff_actions.details"}}</th>
              <th>{{i18n "admin.logs.staff_actions.context"}}</th>
            </thead>
            <tbody>
              {{#each @controller.model.content as |item|}}
                <tr class="admin-list-item" data-user-history-id={{item.id}}>
                  <td class="staff-users">
                    <div class="staff-user">
                      {{#if item.acting_user}}
                        <LinkTo @route="adminUser" @model={{item.acting_user}}>
                          {{avatar item.acting_user imageSize="tiny"}}
                          {{item.acting_user.username}}
                        </LinkTo>
                      {{else}}
                        <span
                          class="deleted-user"
                          title={{i18n "admin.user.deleted"}}
                        >
                          {{icon "trash-can"}}
                        </span>
                      {{/if}}
                    </div>
                  </td>
                  <td class="col value action">
                    <a
                      href
                      {{on "click" (fn @controller.filterByAction item)}}
                    >{{item.actionName}}</a>
                  </td>
                  <td class="col value subject">
                    <div class="subject">
                      {{#if item.target_user}}
                        <LinkTo
                          @route="adminUser"
                          @model={{item.target_user}}
                        >{{avatar item.target_user imageSize="tiny"}}</LinkTo>
                        <a
                          href
                          {{on
                            "click"
                            (fn @controller.filterByTargetUser item.target_user)
                          }}
                        >{{item.target_user.username}}</a>
                      {{/if}}
                      {{#if item.subject}}
                        <a
                          href
                          {{on
                            "click"
                            (fn @controller.filterBySubject item.subject)
                          }}
                          title={{item.subject}}
                        >{{item.subject}}</a>
                      {{/if}}
                    </div>
                  </td>
                  <td class="col value created-at">{{ageWithTooltip
                      item.created_at
                    }}</td>
                  <td class="col value details">
                    <div>
                      {{htmlSafe item.formattedDetails}}
                      {{#if item.useCustomModalForDetails}}
                        <a
                          href
                          {{on
                            "click"
                            (fn @controller.showCustomDetailsModal item)
                          }}
                        >{{icon "circle-info"}}
                          {{i18n "admin.logs.staff_actions.show"}}</a>
                      {{/if}}
                      {{#if item.useModalForDetails}}
                        <a
                          href
                          {{on "click" (fn @controller.showDetailsModal item)}}
                        >{{icon "circle-info"}}
                          {{i18n "admin.logs.staff_actions.show"}}</a>
                      {{/if}}
                    </div>
                  </td>
                  <td class="col value context">{{item.context}}</td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else if @controller.model.loadingMore}}
          <ConditionalLoadingSpinner
            @condition={{@controller.model.loadingMore}}
          />
        {{else}}
          {{i18n "search.no_results"}}
        {{/if}}
      </LoadMore>
    </StaffActions>
  </template>
);
