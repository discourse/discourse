import BlogThemePicker from "../../../../../components/blog-theme-picker.gjs";

export default <template>
  <BlogThemePicker
    @activeOn={{@model.activeOn}}
    @blog={{@model.blog}}
    @themes={{@model.themes}}
  />
</template>
