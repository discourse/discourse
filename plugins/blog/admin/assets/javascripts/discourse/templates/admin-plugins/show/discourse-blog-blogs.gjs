import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "blog.admin.blogs_tab"}}
    @path="/admin/plugins/blog/blogs"
  />
  {{outlet}}
</template>
