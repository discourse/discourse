import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n "admin.config.content.header_description"}}
    @titleLabel={{i18n "admin.config.content.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.content.title"}}
        @path="/admin/config/content"
      />
    </:breadcrumbs>
    <:tabs>
      <DNavItem
        @label="admin.config.content.sub_pages.categories_and_tags.title"
        @route="adminConfig.content.categoriesAndTags"
      />
      <DNavItem
        @label="admin.config.content.sub_pages.sharing.title"
        @route="adminConfig.content.sharing"
      />
      <DNavItem
        @label="admin.config.content.sub_pages.posts_and_topics.title"
        @route="adminConfig.content.postsAndTopics"
      />
      <DNavItem
        @label="admin.config.content.sub_pages.stats_and_thresholds.title"
        @route="adminConfig.content.statsAndThresholds"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-config-page__main-area">
    {{outlet}}
  </div>
</template>
