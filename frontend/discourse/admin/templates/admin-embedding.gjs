import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="admin-embedding admin-config-page">
      <DPageHeader
        @titleLabel={{i18n "admin.config.embedding.title"}}
        @descriptionLabel={{i18n "admin.config.embedding.header_description"}}
        @learnMoreUrl="https://meta.discourse.org/t/embed-discourse-comments-on-another-website-via-javascript/31963"
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
          <DBreadcrumbsItem
            @path="/admin/customize/embedding"
            @label={{i18n "admin.config.embedding.title"}}
          />
        </:breadcrumbs>
        <:actions as |actions|>
          <actions.Primary
            @route="adminEmbedding.new"
            @title="admin.embedding.add_host"
            @label="admin.embedding.add_host"
            class="admin-embedding__header-add-host"
          />
        </:actions>
        <:tabs>
          <NavItem
            @route="adminEmbedding.settings"
            @label="admin.embedding.nav.settings"
            class="admin-embedding-tabs__settings"
          />
          <NavItem
            @route="adminEmbedding.index"
            @label="admin.embedding.nav.hosts"
            class="admin-embedding-tabs__hosts"
          />
          <NavItem
            @route="adminEmbedding.postsAndTopics"
            @label="admin.embedding.nav.posts_and_topics"
            class="admin-embedding-tabs__posts-and-topics"
          />
          <NavItem
            @route="adminEmbedding.crawlers"
            @label="admin.embedding.nav.crawlers"
            class="admin-embedding-tabs__crawlers"
          />
        </:tabs>
      </DPageHeader>

      <div class="admin-container admin-config-page__main-area">
        {{outlet}}
      </div>
    </div>
  </template>
);
