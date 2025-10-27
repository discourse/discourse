import formatDate from "discourse/helpers/format-date";
import routeAction from "discourse/helpers/route-action";
import EmailLogsList from "admin/components/email-logs-list";
import IncomingEmail from "admin/models/incoming-email";

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
        <td>{{formatDate emailLog.created_at}}</td>
        <td>{{emailLog.from_address}}</td>
        <td>{{emailLog.to_addresses}}</td>
        <td>
          <a href={{emailLog.post_url}}>
            {{emailLog.subject}}
          </a>
        </td>
      </tr>
    </:default>
  </EmailLogsList>
</template>
