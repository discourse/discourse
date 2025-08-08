import { array, fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import { gt } from "truth-helpers";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import slice from "discourse/helpers/slice";
import { i18n } from "discourse-i18n";
import EmailLogsList from "admin/components/email-logs-list";
import DTooltip from "float-kit/components/d-tooltip";

const CC_ADDRESS_DISPLAY_THRESHOLD = 2;

const SENT_HEADERS = [
  { key: "admin.email.user" },
  { key: "admin.email.to_address" },
  { key: "admin.email.email_type" },
  { key: "admin.email.reply_key" },
  { key: "admin.email.post_link_with_smtp" },
];

const SENT_FILTERS = [
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
  {
    property: "filterReplyKey",
    name: "reply_key",
    placeholder: "admin.email.logs.filters.reply_key_placeholder",
  },
];

export default RouteTemplate(
  <template>
    <EmailLogsList
      @status="sent"
      @logType="sent"
      @ccAddressDisplayThreshold={{CC_ADDRESS_DISPLAY_THRESHOLD}}
      @headers={{SENT_HEADERS}}
      @filters={{SENT_FILTERS}}
      {{! empty alignment placeholder}}
      @extraFilterCells={{array (hash)}}
    >
      <:default as |emailLog ccThreshold sortWithAddressFilter|>
        <tr class="sent-email-item">
          <td class="sent-email-date">{{formatDate emailLog.created_at}}</td>
          <td class="sent-email-username">
            {{#if emailLog.user}}
              <span class="email-logs-user">
                <LinkTo @route="adminUser" @model={{emailLog.user}}>
                  {{avatar emailLog.user imageSize="tiny"}}
                </LinkTo>
                <LinkTo @route="adminUser" @model={{emailLog.user}}>
                  {{emailLog.user.username}}
                </LinkTo>
              </span>
            {{else}}
              &mdash;
            {{/if}}
          </td>
          <td class="sent-email-address">
            {{#if emailLog.bounced}}
              {{icon "arrow-rotate-right" title="admin.email.bounced"}}
            {{/if}}
            <a href="mailto:{{emailLog.to_address}}" title="TO">
              {{emailLog.to_address}}
            </a>
            {{#if emailLog.cc_addresses}}
              {{#if (gt emailLog.cc_addresses.length ccThreshold)}}
                {{#each
                  (slice
                    0
                    ccThreshold
                    (fn sortWithAddressFilter emailLog.cc_addresses)
                  )
                  as |cc|
                }}
                  <a href="mailto:{{cc}}" title="CC">{{cc}}</a>
                {{/each}}
                <DTooltip
                  @placement="right-start"
                  @arrow={{true}}
                  @identifier="email-log-cc-addresses"
                  @interactive={{true}}
                >
                  <:trigger>
                    {{i18n "admin.email.logs.email_addresses.see_more"}}
                  </:trigger>
                  <:content>
                    <ul>
                      {{#each
                        (slice ccThreshold emailLog.cc_addresses)
                        as |cc|
                      }}
                        <li>
                          <span>
                            <a href="mailto:{{cc}}" title="CC">{{cc}}</a>
                          </span>
                        </li>
                      {{/each}}
                    </ul>
                  </:content>
                </DTooltip>
              {{else}}
                {{#each emailLog.cc_addresses as |cc|}}
                  <a href="mailto:{{cc}}" title="CC">{{cc}}</a>
                {{/each}}
              {{/if}}
            {{/if}}
          </td>
          <td class="sent-email-type">{{emailLog.email_type}}</td>
          <td class="sent-email-reply-key">
            <span
              title={{emailLog.reply_key}}
              class="reply-key"
            >{{emailLog.reply_key}}</span>
          </td>
          <td class="sent-email-post-link-with-smtp-response">
            {{#if emailLog.post_url}}
              <a href={{emailLog.post_url}}>
                {{emailLog.post_description}}
              </a>
              <div>
                {{i18n "admin.email.logs.post_id" post_id=emailLog.post_id}}
              </div>
            {{/if}}
            <code title={{emailLog.smtp_transaction_response}}>
              {{emailLog.smtp_transaction_response}}
            </code>
          </td>
        </tr>
      </:default>
    </EmailLogsList>
  </template>
);
