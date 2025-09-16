import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import avatar from "discourse/helpers/avatar";
import formatDate from "discourse/helpers/format-date";
import EmailLogsList from "admin/components/email-logs-list";

const SKIPPED_HEADERS = [
  { key: "admin.email.user" },
  { key: "admin.email.to_address" },
  { key: "admin.email.email_type" },
  { key: "admin.email.skipped_reason" },
];

const SKIPPED_FILTERS = [
  {
    property: "filterUser",
    name: "user",
    placeholder: "admin.email.logs.filters.user_placeholder",
  },
  {
    property: "filterAddress",
    name: "address",
    placeholder: "admin.email.logs.filters.address_placeholder",
  },
  {
    property: "filterType",
    name: "type",
    placeholder: "admin.email.logs.filters.type_placeholder",
  },
];

export default RouteTemplate(
  <template>
    <EmailLogsList
      @status="skipped"
      @logType="skipped"
      @headers={{SKIPPED_HEADERS}}
      @filters={{SKIPPED_FILTERS}}
    >
      <:default as |emailLog|>
        <tr>
          <td>{{formatDate emailLog.created_at}}</td>
          <td>
            {{#if emailLog.user}}
              <span class="email-logs-user">
                <LinkTo @route="adminUser" @model={{emailLog.user}}>
                  {{avatar emailLog.user imageSize="tiny"}}
                  {{emailLog.user.username}}
                </LinkTo>
              </span>
            {{else}}
              &mdash;
            {{/if}}
          </td>
          <td>
            <a href="mailto:{{emailLog.to_address}}">{{emailLog.to_address}}</a>
          </td>
          <td>{{emailLog.email_type}}</td>
          <td>{{emailLog.skipped_reason}}</td>
        </tr>
      </:default>
    </EmailLogsList>
  </template>
);
