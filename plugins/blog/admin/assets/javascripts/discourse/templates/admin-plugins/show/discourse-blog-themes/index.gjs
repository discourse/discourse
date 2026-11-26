import Component from "@glimmer/component";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import BlogThemeCard from "../../../../components/blog-theme-card.gjs";

// With several blogs, each blog picks its theme on its Theme tab.
function severalBlogs(blogs) {
  return blogs?.length > 1;
}

function activeOn(blogs, theme) {
  if (!severalBlogs(blogs)) {
    return null;
  }
  return blogs
    .filter((blog) => blog.active_theme_id === theme.id)
    .map((blog) => blog.name);
}

export default class BlogThemesIndex extends Component {
  @service siteSettings;

  get customThemesLocked() {
    return !this.siteSettings.blog_custom_themes_enabled;
  }

  <template>
    <section class="blog-themes">
      <DBreadcrumbsItem
        @label={{i18n "blog.admin.themes"}}
        @path="/admin/plugins/blog/themes"
      />
      <div class="blog-admin-intro">
        <p class="blog-admin-intro__description">{{i18n
            "blog.admin.themes_tab_description"
          }}</p>
        <DPageSubheader>
          <:actions as |actions|>
            {{! actions.Default cannot be disabled. }}
            <actions.Wrapped as |wrapped|>
              <DButton
                class={{if
                  wrapped.buttonClass
                  wrapped.buttonClass
                  "d-page-action-button btn-small btn-default"
                }}
                @disabled={{this.customThemesLocked}}
                @label="blog.admin.import"
                @route="adminPlugins.show.discourse-blog-themes.import"
              />
            </actions.Wrapped>
            <actions.Primary
              @disabled={{this.customThemesLocked}}
              @label="blog.admin.new_theme_short"
              @route="adminPlugins.show.discourse-blog-themes.new"
            />
          </:actions>
        </DPageSubheader>
      </div>
      {{#if this.customThemesLocked}}
        <PluginOutlet @name="blog-admin-custom-themes-unavailable" />
      {{/if}}
      <div class="themes-cards-container">
        {{#each @model.themes key="id" as |theme|}}
          <BlogThemeCard
            @activeOn={{activeOn @model.blogs theme}}
            @activeThemeId={{@model.active.id}}
            @hideActivate={{severalBlogs @model.blogs}}
            @theme={{theme}}
          />
        {{/each}}
      </div>
    </section>
  </template>
}
