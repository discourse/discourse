import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
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
        <NavItem
          @route="adminConfig.content.categoriesAndTags"
          @label="admin.config.content.sub_pages.categories_and_tags.title"
        />
        <NavItem
          @route="adminConfig.content.sharing"
          @label="admin.config.content.sub_pages.sharing.title"
        />
        <NavItem
          @route="adminConfig.content.postsAndTopics"
          @label="admin.config.content.sub_pages.posts_and_topics.title"
        />
        <NavItem
          @route="adminConfig.content.statsAndThresholds"
          @label="admin.config.content.sub_pages.stats_and_thresholds.title"
        />
      </:tabs>
    </DPageHeader>

    <div class="admin-config-page__main-area">
      {{outlet}}
    </div>
  </template>
);
