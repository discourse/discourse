import BackButton from "discourse/components/back-button";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import BlogNewForm from "../../../../components/blog-new-form.gjs";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "blog.admin.new_blog"}}
    @path="/admin/plugins/blog/blogs/new"
  />
  <BackButton
    @label="blog.admin.back_to_blogs"
    @route="adminPlugins.show.discourse-blog-blogs.index"
  />
  <BlogNewForm />
</template>
