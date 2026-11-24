import getURL from "discourse/lib/get-url";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import BlogThemeCard from "./blog-theme-card.gjs";

const BlogThemePicker = <template>
  <div class="blog-theme-picker">
    <DPageSubheader
      @descriptionLabel={{i18n
        "blog.admin.theme_tab_description"
        themes_url=(getURL "/admin/plugins/blog/themes")
      }}
      @titleLabel={{i18n "blog.admin.theme_tab"}}
    />
    <div class="themes-cards-container">
      {{#each @themes key="id" as |theme|}}
        <BlogThemeCard
          @activeRevision={{@activeOn.active_revision}}
          @activeThemeId={{@activeOn.active_theme_id}}
          @blog={{@blog}}
          @theme={{theme}}
        />
      {{/each}}
    </div>
  </div>
</template>;

export default BlogThemePicker;
