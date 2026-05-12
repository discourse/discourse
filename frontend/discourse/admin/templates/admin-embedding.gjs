import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
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
        <DNavItem
          @route="adminEmbedding.settings"
          @label="admin.embedding.nav.settings"
          class="admin-embedding-tabs__settings"
        />
        <DNavItem
          @route="adminEmbedding.index"
          @label="admin.embedding.nav.hosts"
          class="admin-embedding-tabs__hosts"
        />
        <DNavItem
          @route="adminEmbedding.postsAndTopics"
          @label="admin.embedding.nav.posts_and_topics"
          class="admin-embedding-tabs__posts-and-topics"
        />
        <DNavItem
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
