import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import HorizontalScrollSyncWrapper from "discourse/components/horizontal-scroll-sync-wrapper";
import LoadMore from "discourse/components/load-more";
import TextField from "discourse/components/text-field";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <LoadMore @action={{@controller.loadMore}}>
      <HorizontalScrollSyncWrapper>
        <table class="table email-list">
          <thead>
            <tr>
              <th>{{i18n "admin.email.time"}}</th>
              <th>{{i18n "admin.email.incoming_emails.from_address"}}</th>
              <th>{{i18n "admin.email.incoming_emails.to_addresses"}}</th>
              <th>{{i18n "admin.email.incoming_emails.subject"}}</th>
              <th colspan="2">{{i18n "admin.email.incoming_emails.error"}}</th>
            </tr>
          </thead>

          <tbody>
            <tr class="filters">
              <td>{{i18n "admin.email.logs.filters.title"}}</td>
              <td>
                <TextField
                  @value={{@controller.filter.from}}
                  @placeholderKey="admin.email.incoming_emails.filters.from_placeholder"
                /></td>
              <td>
                <TextField
                  @value={{@controller.filter.to}}
                  @placeholderKey="admin.email.incoming_emails.filters.to_placeholder"
                /></td>
              <td>
                <TextField
                  @value={{@controller.filter.subject}}
                  @placeholderKey="admin.email.incoming_emails.filters.subject_placeholder"
                /></td>
              <td colspan="2">
                <TextField
                  @value={{@controller.filter.error}}
                  @placeholderKey="admin.email.incoming_emails.filters.error_placeholder"
                /></td>
            </tr>

            {{#each @controller.model as |email|}}
              <tr>
                <td class="time">{{formatDate email.created_at}}</td>
                <td class="username">
                  <div>
                    {{#if email.user}}
                      <span class="email-logs-user">
                        <LinkTo @route="adminUser" @model={{email.user}}>
                          {{avatar email.user imageSize="tiny"}}
                          {{email.from_address}}
                        </LinkTo>
                      </span>
                    {{else}}
                      {{#if email.from_address}}
                        <a
                          href="mailto:{{email.from_address}}"
                        >{{email.from_address}}</a>
                      {{else}}
                        &mdash;
                      {{/if}}
                    {{/if}}
                  </div>
                </td>
                <td class="addresses">
                  {{#each email.to_addresses as |to|}}
                    <a href="mailto:{{to}}" title="TO">{{to}}</a>
                  {{/each}}
                  {{#each email.cc_addresses as |cc|}}
                    <a href="mailto:{{cc}}" title="CC">{{cc}}</a>
                  {{/each}}
                </td>
                <td>{{email.subject}}</td>
                <td class="error">
                  <a
                    href
                    {{on
                      "click"
                      (fn @controller.handleShowIncomingEmail email.id)
                    }}
                  >{{email.error}}</a>
                </td>
                <td class="email-details">
                  <a
                    href
                    {{on
                      "click"
                      (fn @controller.handleShowIncomingEmail email.id)
                    }}
                    title={{i18n "admin.email.details_title"}}
                  >
                    {{icon "circle-info"}}
                  </a>
                </td>
              </tr>
            {{else}}
              <tr>
                <td colspan="6">{{i18n
                    "admin.email.incoming_emails.none"
                  }}</td></tr>
            {{/each}}
          </tbody>
        </table>
      </HorizontalScrollSyncWrapper>
    </LoadMore>

    <ConditionalLoadingSpinner @condition={{@controller.loading}} />
  </template>
);
