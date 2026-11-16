import { array } from "@ember/helper";
import BlogThemeEditor from "../../../../components/blog-theme-editor.gjs";

export default <template>
  {{! Remount per model so the form starts over from the chosen theme. }}
  {{#each (array @model) as |model|}}
    <BlogThemeEditor @model={{model}} />
  {{/each}}
</template>
