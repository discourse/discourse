import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.content.title"}}
    @descriptionLabel={{i18n "admin.config.content.header_description"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/config/content"
        @label={{i18n "admin.config.content.title"}}
      />
    </:breadcrumbs>
    <:tabs>
      <DNavItem
        @route="adminConfig.content.categoriesAndTags"
        @label="admin.config.content.sub_pages.categories_and_tags.title"
      />
      <DNavItem
        @route="adminConfig.content.sharing"
        @label="admin.config.content.sub_pages.sharing.title"
      />
      <DNavItem
        @route="adminConfig.content.postsAndTopics"
        @label="admin.config.content.sub_pages.posts_and_topics.title"
      />
      <DNavItem
        @route="adminConfig.content.statsAndThresholds"
        @label="admin.config.content.sub_pages.stats_and_thresholds.title"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-config-page__main-area">
    {{outlet}}
  </div>
</template>
