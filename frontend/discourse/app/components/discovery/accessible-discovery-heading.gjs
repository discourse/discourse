import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class AccessibleDiscoveryHeading extends Component {
  get filterKey() {
    const filter = this.args.filter;

    if (!filter || filter === "categories") {
      return null;
    }

    if (filter.includes("/")) {
      return filter.split("/").pop();
    }

    return filter;
  }

  get type() {
    const { category, tag, additionalTags } = this.args;

    if (category && tag) {
      return "category_tag";
    }

    if (tag && additionalTags?.length) {
      return "multi_tag";
    }

    if (tag) {
      return "single_tag";
    }

    if (category) {
      return "category";
    }

    return "all";
  }

  get label() {
    const { category, tag, additionalTags, filter } = this.args;
    const key = this.filterKey;
    const type = this.type;

    if (filter === "categories") {
      return i18n("discovery.headings.categories");
    }

    // tag intersections don't have additional filters
    if (type === "multi_tag") {
      return i18n("discovery.headings.multi_tag.default", {
        tags: [tag?.id, ...(additionalTags || [])].filter(Boolean).join(" + "),
      });
    }

    if (tag?.id === "none" && !additionalTags?.length) {
      const noTagsType = category ? "category" : "all";
      const prefix = `discovery.headings.no_tags.${noTagsType}`;
      const specificKey = key ? `${prefix}.${key}` : null;
      const fallbackKey = `${prefix}.default`;

      const params = {
        category: category?.name,
        filter: key,
      };

      let label = specificKey ? i18n(specificKey, params) : "";
      if (label === specificKey || label.includes("discovery.headings")) {
        label = i18n(fallbackKey, params);
      }

      return label;
    }

    const base = `discovery.headings.${type}`;
    const specificKey = key ? `${base}.${key}` : null;
    const fallbackKey = `${base}.default`;

    const params = {
      category: category?.name,
      tag: tag?.id,
      filter: key,
    };

    let label = specificKey ? i18n(specificKey, params) : "";
    if (label === specificKey || label.includes("discovery.headings")) {
      label = i18n(fallbackKey, params);
    }

    return label;
  }

  <template>
    {{#if @filter}}
      <h1 id="topic-list-heading" class="sr-only">{{this.label}}</h1>
    {{/if}}
  </template>
}
