<LoadMore @selector=".email-list tr" @action={{action "loadMore"}}>
  <table class="table email-list">
    <thead>
      <tr>
        <th>{{i18n "admin.email.time"}}</th>
        <th>{{i18n "admin.email.user"}}</th>
        <th>{{i18n "admin.email.to_address"}}</th>
        <th>{{i18n "admin.email.email_type"}}</th>
        <th>{{i18n "admin.email.skipped_reason"}}</th>
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
        <td></td>
      </tr>

      {{#each this.model as |l|}}
        <tr>
          <td>{{format-date l.created_at}}</td>
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
          <td>{{l.email_type}}</td>
          <td>
            {{#if l.post_url}}
              <a href={{l.post_url}}>{{l.skipped_reason}}</a>
            {{else}}
              {{l.skipped_reason}}
            {{/if}}
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