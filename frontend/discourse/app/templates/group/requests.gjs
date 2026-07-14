import { fn } from "@ember/helper";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DResponsiveTable from "discourse/ui-kit/d-responsive-table";
import DTableHeaderToggle from "discourse/ui-kit/d-table-header-toggle";
import DTextField from "discourse/ui-kit/d-text-field";
import DUserInfo from "discourse/ui-kit/d-user-info";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if (or @controller.loading @controller.canLoadMore)}}
    {{hideApplicationFooter}}
  {{/if}}

  <section class="user-content">
    <div class="group-members-actions">
      <DTextField
        @value={{@controller.filterInput}}
        @placeholderKey={{@controller.filterPlaceholder}}
        class="group-username-filter no-blur"
      />
    </div>

    {{#if @controller.hasRequesters}}
      <DLoadMore @action={{@controller.loadMore}}>
        <DResponsiveTable @className="group-members group-members__requests">
          <:header>
            <DTableHeaderToggle
              @onToggle={{@controller.updateOrder}}
              @order={{@controller.order}}
              @asc={{@controller.asc}}
              @field="username_lower"
              @labelKey="username"
              @automatic={{true}}
              class="username"
            />
            <DTableHeaderToggle
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
                  <DUserInfo @user={{m}} @skipName={{@controller.skipName}} />
                </div>
                <div class="directory-table__cell">
                  <span class="directory-table__label">
                    <span>{{i18n "groups.member_requested"}}</span>
                  </span>
                  <span class="directory-table__value">
                    {{dAgeWithTooltip m.requested_at format="medium"}}
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
        </DResponsiveTable>
      </DLoadMore>
      <DConditionalLoadingSpinner @condition={{@controller.loading}} />
    {{else}}
      <div>{{i18n "groups.empty.requests"}}</div>
    {{/if}}
  </section>
</template>
