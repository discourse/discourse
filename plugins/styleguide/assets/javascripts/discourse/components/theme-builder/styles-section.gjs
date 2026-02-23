import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import STYLE_SNIPPETS from "discourse/plugins/styleguide/discourse/lib/theme-builder-style-snippets";

const GROUPS = ["layout", "buttons"];

export default class ThemeBuilderStylesSection extends Component {
  @service themeBuilderState;

  isSnippetActive = (snippetId) =>
    this.themeBuilderState.activeSnippetIds.includes(snippetId);

  get groupedSnippets() {
    return GROUPS.map((group) => ({
      group,
      snippets: STYLE_SNIPPETS.filter((s) => s.group === group),
    }));
  }

  @action
  toggleSnippet(snippetId) {
    this.themeBuilderState.toggleSnippet(snippetId);
  }

  <template>
    <div class="theme-builder-styles-section">
      {{#each this.groupedSnippets as |section|}}
        <h4 class="theme-builder-styles-section__heading">{{i18n
            (concat "styleguide.theme_builder.styles.groups." section.group)
          }}</h4>
        {{#each section.snippets as |snippet|}}
          <label class="theme-builder-styles-section__item">
            <input
              type="checkbox"
              checked={{this.isSnippetActive snippet.id}}
              {{on "change" (fn this.toggleSnippet snippet.id)}}
            />
            <span>{{i18n
                (concat "styleguide.theme_builder.styles." snippet.id)
              }}</span>
          </label>
        {{/each}}
      {{/each}}
    </div>
  </template>
}
