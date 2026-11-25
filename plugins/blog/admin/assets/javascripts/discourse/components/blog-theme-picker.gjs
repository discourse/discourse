import BlogThemeCard from "./blog-theme-card.gjs";

const BlogThemePicker = <template>
  <div class="blog-theme-picker">
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
