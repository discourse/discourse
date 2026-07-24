import EmailLogsList from "discourse/admin/components/email-logs-list";
import IncomingEmail from "discourse/admin/models/incoming-email";
import routeAction from "discourse/helpers/route-action";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";

const RECEIVED_HEADERS = [
  { key: "admin.email.incoming_emails.from_address" },
  { key: "admin.email.incoming_emails.to_addresses" },
  { key: "admin.email.incoming_emails.subject" },
];

const RECEIVED_FILTERS = [
  {
    property: "filterFrom",
    name: "from",
    placeholder: "admin.email.incoming_emails.filters.from_placeholder",
  },
  {
    property: "filterTo",
    name: "to",
    placeholder: "admin.email.incoming_emails.filters.to_placeholder",
  },
  {
    property: "filterSubject",
    name: "subject",
    placeholder: "admin.email.incoming_emails.filters.subject_placeholder",
  },
];

export default <template>
  <EmailLogsList
    @status="received"
    @logType="received"
    @sourceModel={{IncomingEmail}}
    @headers={{RECEIVED_HEADERS}}
    @filters={{RECEIVED_FILTERS}}
    @onShowEmail={{routeAction "showIncomingEmail"}}
  >
    <:default as |emailLog|>
      <tr data-test-email-log-row-id={{emailLog.id}}>
        <td>{{dFormatDate emailLog.created_at}}</td>
        <td>{{emailLog.from_address}}</td>
        <td>{{emailLog.to_addresses}}</td>
        <td>
          {{#if emailLog.post_url}}
            <a href={{emailLog.post_url}}>
              {{emailLog.subject}}
            </a>
          {{else}}
            {{emailLog.subject}}
          {{/if}}
        </td>
      </tr>
    </:default>
  </EmailLogsList>
</template>
