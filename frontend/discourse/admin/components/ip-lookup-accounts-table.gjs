import { LinkTo } from "@ember/routing";
import avatar from "discourse/helpers/avatar";
import { i18n } from "discourse-i18n";

const IpLookupAccountsTable = <template>
  <table class="ip-lookup-table">
    <thead>
      <tr>
        <th>{{i18n "ip_lookup.username"}}</th>
        <th>{{i18n "ip_lookup.trust_level"}}</th>
        <th>{{i18n "ip_lookup.read_time"}}</th>
        <th>{{i18n "ip_lookup.topics_entered"}}</th>
        <th>{{i18n "ip_lookup.post_count"}}</th>
      </tr>
    </thead>
    <tbody>
      {{#each @accounts as |account|}}
        <tr>
          <td class="user">
            <LinkTo @route="adminUser" @model={{account}}>
              {{avatar account imageSize="tiny"}}
              <span>{{account.username}}</span>
            </LinkTo>
          </td>
          <td>{{account.trustLevel.id}}</td>
          <td>{{account.time_read}}</td>
          <td>{{account.topics_entered}}</td>
          <td>{{account.post_count}}</td>
        </tr>
      {{/each}}
    </tbody>
  </table>
</template>;

export default IpLookupAccountsTable;
