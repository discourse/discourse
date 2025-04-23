import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class DiscoveryHeading extends Component {
  get filterKey() {
    const mode = this.args.filterMode;

    if (typeof mode === "string" && mode.includes("/")) {
      return mode.split("/").pop();
    }

    return mode || "latest";
  }

  get filterLabel() {
    return i18n(`discovery.headings.filter_labels.${this.filterKey}`);
  }

  get label() {
    const { category, tag, additionalTags } = this.args;
    const filter = this.filterLabel;

    if (category && tag) {
      const tagList = [tag?.id, ...(additionalTags || [])].join(" + ");
      return i18n("discovery.headings.category_tag", {
        category: category.name,
        tags: tagList,
        filter,
      });
    }

    if (tag) {
      if (additionalTags?.length) {
        return i18n("discovery.headings.multi_tag", {
          tags: [tag.id, ...additionalTags].join(" and "),
          filter,
        });
      }
      return i18n("discovery.headings.single_tag", { tag: tag.id, filter });
    }

    if (category) {
      return i18n("discovery.headings.category", {
        category: category.name,
        filter: this.filterLabel,
      });
    }

    return i18n("discovery.headings.all", { filter });
  }

  <template>
    <h1>{{this.label}}</h1>
  </template>
}
