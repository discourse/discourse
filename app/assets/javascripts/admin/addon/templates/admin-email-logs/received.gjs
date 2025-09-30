import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import formatDate from "discourse/helpers/format-date";
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

export default RouteTemplate(
  <template>
    <EmailLogsList
      @status="received"
      @logType="received"
      @sourceModel={{IncomingEmail}}
      @headers={{RECEIVED_HEADERS}}
      @filters={{RECEIVED_FILTERS}}
    >
      <:default
        as |emailLog ccThreshold sortWithAddressFilter handleShowIncomingEmail|
      >
        <tr data-test-email-log-row-id={{emailLog.id}}>
          <td>{{formatDate emailLog.created_at}}</td>
          <td>{{emailLog.from_address}}</td>
          <td>{{emailLog.to_addresses}}</td>
          <td>
            <a
              href
              {{on "click" (fn handleShowIncomingEmail emailLog.id)}}
              class="incoming-email-link"
            >
              {{emailLog.subject}}
            </a>
          </td>
        </tr>
      </:default>
    </EmailLogsList>
  </template>
);
