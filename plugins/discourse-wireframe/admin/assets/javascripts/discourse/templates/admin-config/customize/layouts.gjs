import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import DesignsList from "discourse/plugins/discourse-wireframe/discourse/components/admin/designs-list";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "wireframe.admin.designs.title"}}
    @path="/admin/config/customize/layouts"
  />

  <DesignsList @designs={{@model}} />
</template>
