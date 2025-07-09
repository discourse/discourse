import { i18n } from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import ApiKeyItem from "admin/components/api-key-item";

const ApiKeysList = <template>
  <div class="container admin-api_keys">
    {{#if @apiKeys}}
      <table class="d-table admin-api_keys__items">
        <thead class="d-table__header">
          <tr class="d-table__row">
            <th class="d-table__header-cell">{{i18n "admin.api.key"}}</th>
            <th class="d-table__header-cell">{{i18n "admin.api.description"}}</th>
            <th class="d-table__header-cell">{{i18n "admin.api.user"}}</th>
            <th class="d-table__header-cell">{{i18n "admin.api.created"}}</th>
            <th class="d-table__header-cell">{{i18n "admin.api.scope"}}</th>
            <th class="d-table__header-cell">{{i18n "admin.api.last_used"}}</th>
          </tr>
        </thead>
        <tbody class="d-table__body">
          {{#each @apiKeys as |apiKey|}}
            <ApiKeyItem @apiKey={{apiKey}} />
          {{/each}}
        </tbody>
      </table>
    {{else}}
      <AdminConfigAreaEmptyList
        @ctaLabel="admin.api_keys.add"
        @ctaRoute="adminApiKeys.new"
        @ctaClass="admin-api_keys__add-api_key"
        @emptyLabel="admin.api_keys.no_api_keys"
      />
    {{/if}}
  </div>
</template>;

export default ApiKeysList;
