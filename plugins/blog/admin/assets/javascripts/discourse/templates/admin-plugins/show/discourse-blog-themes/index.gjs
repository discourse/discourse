import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import BlogThemeCard from "../../../../components/blog-theme-card.gjs";

export default <template>
  <section class="blog-themes">
    <DBreadcrumbsItem
      @label={{i18n "blog.admin.themes"}}
      @path="/admin/plugins/blog/themes"
    />
    <DPageSubheader
      @descriptionLabel={{i18n "blog.admin.themes_index_description"}}
      @titleLabel={{i18n "blog.admin.themes"}}
    >
      <:actions as |actions|>
        <actions.Default
          @label="blog.admin.import"
          @route="adminPlugins.show.discourse-blog-themes.import"
        />
        <actions.Primary
          @label="blog.admin.new_theme_short"
          @route="adminPlugins.show.discourse-blog-themes.new"
        />
      </:actions>
    </DPageSubheader>
    {{#if @model.themes.length}}
      <div class="themes-cards-container">
        {{#each @model.themes key="id" as |theme|}}
          <BlogThemeCard @activeThemeId={{@model.active.id}} @theme={{theme}} />
        {{/each}}
      </div>
    {{else}}
      <DEmptyState
        @body={{i18n "blog.admin.no_themes_description"}}
        @title={{i18n "blog.admin.no_themes"}}
      />
    {{/if}}
  </section>
</template>
