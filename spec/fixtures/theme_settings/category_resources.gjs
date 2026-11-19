import Component from "@glimmer/component";
import { settings, themePrefix } from "virtual:theme";
import { block } from "discourse/blocks";
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

@block("theme:object-translations:resources", {
  args: { section: { type: "object", required: true } },
})
class Resources extends Component {
  get links() {
    const section = this.args.section;
    return section.links.map((link) => {
      const prefix = `resource_sections.${section.translation_key}.links.${link.translation_key}`;
      return {
        label: i18n(themePrefix(`${prefix}.label`), {
          defaultValue: link.label,
        }),
        description: i18n(themePrefix(`${prefix}.description`), {
          defaultValue: link.description,
        }),
        destination: link.destination,
      };
    });
  }

  <template>
    <ul class="category-resources">
      {{#each this.links as |link|}}
        <li>
          <a href={{link.destination}}>{{link.label}}</a>
          <p>{{link.description}}</p>
        </li>
      {{/each}}
    </ul>
  </template>
}

export default apiInitializer((api) => {
  api.renderBlocks(
    "sidebar-discovery",
    settings.resource_sections.map((section) => ({
      block: Resources,
      args: { section },
      conditions: {
        type: "outlet-arg",
        path: "category.id",
        value: section.categories,
      },
    }))
  );
});
