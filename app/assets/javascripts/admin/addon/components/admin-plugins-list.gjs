import { i18n } from "discourse-i18n";
import AdminPluginsListItem from "./admin-plugins-list-item";

const AdminPluginsList = <template>
  <table class="d-table admin-plugins-list">
    <thead class="d-table__header">
      <tr class="d-table__row">
        <th class="d-table__header-cell">{{i18n "admin.plugins.name"}}</th>
        <th class="d-table__header-cell">{{i18n "admin.plugins.version"}}</th>
        <th class="d-table__header-cell">{{i18n "admin.plugins.enabled"}}</th>
        <th class="d-table__header-cell"></th>
      </tr>
    </thead>
    <tbody class="d-table__body">
      {{#each @plugins as |plugin|}}
        <AdminPluginsListItem @plugin={{plugin}} />
      {{/each}}
    </tbody>
  </table>
</template>;

export default AdminPluginsList;
