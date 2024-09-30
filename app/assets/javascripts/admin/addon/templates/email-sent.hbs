<LoadMore @selector=".email-list tr" @action={{action "loadMore"}}>
  <table class="table email-list">
    <thead>
      <tr>
        <th>{{i18n "admin.email.sent_at"}}</th>
        <th>{{i18n "admin.email.user"}}</th>
        <th>{{i18n "admin.email.to_address"}}</th>
        <th>{{i18n "admin.email.email_type"}}</th>
        <th>{{i18n "admin.email.reply_key"}}</th>
        <th>{{i18n "admin.email.post_link_with_smtp"}}</th>
      </tr>
    </thead>
    <tbody>
      <tr class="filters">
        <td>{{i18n "admin.email.logs.filters.title"}}</td>
        <td><TextField
            @value={{this.filter.user}}
            @placeholderKey="admin.email.logs.filters.user_placeholder"
          /></td>
        <td><TextField
            @value={{this.filter.address}}
            @placeholderKey="admin.email.logs.filters.address_placeholder"
          /></td>
        <td><TextField
            @value={{this.filter.type}}
            @placeholderKey="admin.email.logs.filters.type_placeholder"
          /></td>
        <td><TextField
            @value={{this.filter.reply_key}}
            @placeholderKey="admin.email.logs.filters.reply_key_placeholder"
          /></td>
        <td></td>
      </tr>

      {{#each this.model as |l|}}
        <tr class="sent-email-item">
          <td class="sent-email-date">{{format-date l.created_at}}</td>
          <td class="sent-email-username">
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
          <td class="sent-email-address">
            {{#if l.bounced}}{{d-icon
                "arrow-rotate-right"
                title="admin.email.bounced"
              }}{{/if}}
            <p><a
                href="mailto:{{l.to_address}}"
                title="TO"
              >{{l.to_address}}</a></p>
            {{#if l.cc_addresses}}
              {{#if (gt l.cc_addresses.length this.ccAddressDisplayThreshold)}}
                {{#each
                  (slice
                    0
                    this.ccAddressDisplayThreshold
                    (fn this.sortWithAddressFilter l.cc_addresses)
                  )
                  as |cc|
                }}
                  <p><a href="mailto:{{cc}}" title="CC">{{cc}}</a></p>
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
                        (slice this.ccAddressDisplayThreshold l.cc_addresses)
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
                {{#each l.cc_addresses as |cc|}}
                  <p><a href="mailto:{{cc}}" title="CC">{{cc}}</a></p>
                {{/each}}
              {{/if}}
            {{/if}}
          </td>
          <td class="sent-email-type">{{l.email_type}}</td>
          <td class="sent-email-reply-key">
            <span title={{l.reply_key}} class="reply-key">{{l.reply_key}}</span>
          </td>
          <td class="sent-email-post-link-with-smtp-response">
            {{#if l.post_url}}
              <a href={{l.post_url}}>
                {{l.post_description}}
              </a>
              {{i18n "admin.email.logs.post_id" post_id=l.post_id}}
              <br />
              /{{/if}}
            <code
              title={{l.smtp_transaction_response}}
            >{{l.smtp_transaction_response}}</code>
          </td>
        </tr>
      {{else}}
        {{#unless this.loading}}
          <tr><td colspan="5">{{i18n "admin.email.logs.none"}}</td></tr>
        {{/unless}}
      {{/each}}
    </tbody>
  </table>
</LoadMore>

<ConditionalLoadingSpinner @condition={{this.loading}} />