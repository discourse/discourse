import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import TextField from "discourse/components/text-field";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <LoadMore @action={{@controller.loadMore}}>
      <table class="table email-list">
        <thead>
          <tr>
            <th>{{i18n "admin.email.time"}}</th>
            <th>{{i18n "admin.email.user"}}</th>
            <th>{{i18n "admin.email.to_address"}}</th>
            <th colspan="2">{{i18n "admin.email.email_type"}}</th>
          </tr>
        </thead>
        <tbody>
          <tr class="filters">
            <td>{{i18n "admin.email.logs.filters.title"}}</td>
            <td>
              <TextField
                @value={{@controller.filter.user}}
                @placeholderKey="admin.email.logs.filters.user_placeholder"
              /></td>
            <td>
              <TextField
                @value={{@controller.filter.address}}
                @placeholderKey="admin.email.logs.filters.address_placeholder"
              /></td>
            <td colspan="2">
              <TextField
                @value={{@controller.filter.type}}
                @placeholderKey="admin.email.logs.filters.type_placeholder"
              /></td>
          </tr>

          {{#each @controller.model as |l|}}
            <tr>
              <td>{{formatDate l.created_at}}</td>
              <td>
                {{#if l.user}}
                  <LinkTo @route="adminUser" @model={{l.user}}>{{avatar
                      l.user
                      imageSize="tiny"
                    }}</LinkTo>
                  <LinkTo
                    @route="adminUser"
                    @model={{l.user}}
                  >{{l.user.username}}</LinkTo>
                {{else}}
                  &mdash;
                {{/if}}
              </td>
              <td class="email-address"><a
                  href="mailto:{{l.to_address}}"
                >{{l.to_address}}</a></td>
              <td>
                {{#if l.has_bounce_key}}
                  <a
                    href
                    {{on "click" (fn @controller.handleShowIncomingEmail l.id)}}
                  >
                    {{l.email_type}}
                  </a>
                {{else}}
                  {{l.email_type}}
                {{/if}}
              </td>
              <td class="email-details">
                {{#if l.has_bounce_key}}
                  <a
                    href
                    {{on "click" (fn @controller.handleShowIncomingEmail l.id)}}
                    title={{i18n "admin.email.details_title"}}
                  >
                    {{icon "circle-info"}}
                  </a>
                {{/if}}
              </td>
            </tr>
          {{else}}
            {{#unless @controller.loading}}
              <tr>
                <td colspan="5">{{i18n "admin.email.logs.none"}}</td></tr>
            {{/unless}}
          {{/each}}
        </tbody>
      </table>
    </LoadMore>

    <ConditionalLoadingSpinner @condition={{@controller.loading}} />
  </template>
);
