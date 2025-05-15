import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import { or } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import ResponsiveTable from "discourse/components/responsive-table";
import TableHeaderToggle from "discourse/components/table-header-toggle";
import TextField from "discourse/components/text-field";
import UserInfo from "discourse/components/user-info";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{#if (or @controller.loading @controller.canLoadMore)}}
      {{hideApplicationFooter}}
    {{/if}}

    <section class="user-content">
      <div class="group-members-actions">
        <TextField
          @value={{@controller.filterInput}}
          @placeholderKey={{@controller.filterPlaceholder}}
          class="group-username-filter no-blur"
        />
      </div>

      {{#if @controller.hasRequesters}}
        <LoadMore @action={{@controller.loadMore}}>
          <ResponsiveTable @className="group-members group-members__requests">
            <:header>
              <TableHeaderToggle
                @onToggle={{@controller.updateOrder}}
                @order={{@controller.order}}
                @asc={{@controller.asc}}
                @field="username_lower"
                @labelKey="username"
                @automatic={{true}}
                class="username"
              />
              <TableHeaderToggle
                @onToggle={{@controller.updateOrder}}
                @order={{@controller.order}}
                @asc={{@controller.asc}}
                @field="requested_at"
                @labelKey="groups.member_requested"
                @automatic={{true}}
              />
              <div
                class="directory-table__column-header group-request-reason__column-header"
              >{{i18n "groups.requests.reason"}}</div>
              <div class="directory-table__column-header"></div>
            </:header>
            <:body>
              {{#each @controller.model.requesters as |m|}}
                <div class="directory-table__row">
                  <div class="directory-table__cell group-member">
                    <UserInfo @user={{m}} @skipName={{@controller.skipName}} />
                  </div>
                  <div class="directory-table__cell">
                    <span class="directory-table__label">
                      <span>{{i18n "groups.member_requested"}}</span>
                    </span>
                    <span class="directory-table__value">
                      {{ageWithTooltip m.requested_at format="medium"}}
                    </span>
                  </div>
                  <div
                    class="directory-table__cell group-request-reason__content"
                  >
                    <span class="directory-table__label">
                      <span>{{i18n "groups.requests.reason"}}</span>
                    </span>
                    <span class="directory-table__value">
                      {{m.reason}}
                    </span>
                  </div>
                  <div class="directory-table__cell group-accept-deny-buttons">
                    {{#if m.request_undone}}
                      {{i18n "groups.requests.undone"}}
                    {{else if m.request_accepted}}
                      {{i18n "groups.requests.accepted"}}
                      <DButton
                        @action={{fn @controller.undoAcceptRequest m}}
                        @label="groups.requests.undo"
                      />
                    {{else if m.request_denied}}
                      {{i18n "groups.requests.denied"}}
                    {{else}}
                      <DButton
                        @action={{fn @controller.acceptRequest m}}
                        @label="groups.requests.accept"
                        class="btn-primary"
                      />
                      <DButton
                        @action={{fn @controller.denyRequest m}}
                        @label="groups.requests.deny"
                        class="btn-danger"
                      />
                    {{/if}}
                  </div>
                </div>
              {{/each}}
            </:body>
          </ResponsiveTable>
        </LoadMore>
        <ConditionalLoadingSpinner @condition={{@controller.loading}} />
      {{else}}
        <div>{{i18n "groups.empty.requests"}}</div>
      {{/if}}
    </section>
  </template>
);
