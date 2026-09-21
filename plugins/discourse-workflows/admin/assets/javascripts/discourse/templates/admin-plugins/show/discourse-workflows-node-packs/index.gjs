import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import NodePackManager from "discourse/plugins/discourse-workflows/admin/components/workflows/node-pack/manager";

export default <template>
  <div class="admin-config-page__main-area workflows-node-packs">
    <DBreadcrumbsItem @label={{i18n "discourse_workflows.node_packs.title"}} />
    <NodePackManager />
  </div>
</template>
