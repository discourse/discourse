import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import NodePackDetail from "discourse/plugins/discourse-workflows/admin/components/workflows/node-pack/detail";

export default <template>
  <div class="admin-config-page__main-area workflows-node-packs">
    <DBreadcrumbsItem
      @label={{i18n "discourse_workflows.node_packs.title"}}
      @path="/admin/plugins/discourse-workflows/node-packs"
    />
    <NodePackDetail @id={{@model}} />
  </div>
</template>
