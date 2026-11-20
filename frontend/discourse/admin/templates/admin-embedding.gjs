import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-embedding admin-config-page">
    <DPageHeader
      @descriptionLabel={{i18n "admin.config.embedding.header_description"}}
      @learnMoreUrl="https://meta.discourse.org/t/embed-discourse-comments-on-another-website-via-javascript/31963"
      @titleLabel={{i18n "admin.config.embedding.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.embedding.title"}}
          @path="/admin/customize/embedding"
        />
      </:breadcrumbs>
      <:actions as |actions|>
        <actions.Primary
          class="admin-embedding__header-add-host"
          @label="admin.embedding.add_host"
          @route="adminEmbedding.new"
          @title="admin.embedding.add_host"
        />
      </:actions>
      <:tabs>
        <DNavItem
          class="admin-embedding-tabs__settings"
          @label="admin.embedding.nav.settings"
          @route="adminEmbedding.settings"
        />
        <DNavItem
          class="admin-embedding-tabs__hosts"
          @label="admin.embedding.nav.hosts"
          @route="adminEmbedding.index"
        />
        <DNavItem
          class="admin-embedding-tabs__posts-and-topics"
          @label="admin.embedding.nav.posts_and_topics"
          @route="adminEmbedding.postsAndTopics"
        />
        <DNavItem
          class="admin-embedding-tabs__crawlers"
          @label="admin.embedding.nav.crawlers"
          @route="adminEmbedding.crawlers"
        />
      </:tabs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      {{outlet}}
    </div>
  </div>
</template>
