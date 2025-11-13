import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import EmailLogsList from "discourse/admin/components/email-logs-list";
import IncomingEmailModal from "discourse/admin/components/modal/incoming-email";
import IncomingEmail from "discourse/admin/models/incoming-email";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

const BOUNCED_HEADERS = [
  { key: "admin.email.user" },
  { key: "admin.email.to_address" },
  { key: "admin.email.bounced", colspan: "2" },
];

const BOUNCED_FILTERS = [
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

export default class AdminEmailLogsBounced extends Component {
  @service modal;

  @action
  async showIncomingEmail(id) {
    const model = await this.loadFromBounced(id);
    this.modal.show(IncomingEmailModal, { model });
  }

  @bind
  async loadFromBounced(id) {
    try {
      return await IncomingEmail.findByBounced(id);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <EmailLogsList
      @status="bounced"
      @logType="bounced"
      @headers={{BOUNCED_HEADERS}}
      @filters={{BOUNCED_FILTERS}}
      @onShowEmail={{this.showIncomingEmail}}
    >
      <:default
        as |emailLog ccThreshold sortWithAddressFilter handleShowIncomingEmail|
      >
        <tr data-test-email-log-row-id={{emailLog.id}}>
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
          <td class="email-details">
            {{#if emailLog.has_bounce_key}}
              <a
                href
                {{on "click" (fn handleShowIncomingEmail emailLog.id)}}
                title={{i18n "admin.email.details_title"}}
              >
                {{icon "circle-info"}}
              </a>
            {{/if}}
          </td>
        </tr>
      </:default>
    </EmailLogsList>
  </template>
}
