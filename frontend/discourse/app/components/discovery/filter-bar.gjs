import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import FilterNavigationBuilder from "discourse/components/discovery/filter-navigation-builder";
import { findCategory } from "discourse/components/discovery/filter-navigation-token";
import {
  parseFilterToken,
  splitFilterQuery,
} from "discourse/lib/filter-query-tokens";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import NavItem from "discourse/models/nav-item";

const UNTAGGED = "none";

/**
 * The category and tag of a topic list, shown as filter tokens. Edits that a
 * category or tag URL can express stay on those lists; anything more opens
 * the filter page.
 */
export default class DiscoveryFilterBar extends Component {
  @service filterOptions;

  constructor() {
    super(...arguments);
    this.filterOptions.load();
  }

  get query() {
    const { category, tag, additionalTags, noSubcategories } = this.args;
    const tokens = [];

    if (category) {
      const prefix = noSubcategories ? "=" : "";
      tokens.push(`${prefix}category:${Category.slugFor(category, ":")}`);
    }

    if (tag?.slug === UNTAGGED && !tag.id) {
      tokens.push("in:untagged");
    } else if (tag) {
      tokens.push(`tag:${[tag.name, ...(additionalTags || [])].join("+")}`);
    }

    return tokens.join(" ");
  }

  // the category list can't be narrowed down, so other filters land on latest
  get listFilter() {
    return this.args.filterType === "categories"
      ? "latest"
      : this.args.filterType || "latest";
  }

  /**
   * The list URL for a query of at most one category and one tag (or one tag
   * intersection on its own), or null when only the filter page can show it.
   */
  urlFor(query) {
    let category;
    let noSubcategories = false;
    let tagNames;

    for (const { filterName, prefix, value } of splitFilterQuery(query).map(
      parseFilterToken
    )) {
      if (!value || value.includes(",")) {
        return null;
      }

      if (
        ["category", "categories"].includes(filterName) &&
        ["", "="].includes(prefix) &&
        !category
      ) {
        category = findCategory(value);
        noSubcategories = prefix === "=";

        if (!category) {
          return null;
        }
      } else if (["tag", "tags"].includes(filterName) && !prefix && !tagNames) {
        tagNames = value.split("+");
      } else {
        return null;
      }
    }

    if (tagNames?.length > 1) {
      return category
        ? null
        : getURL(
            `/tags/intersection/${tagNames.map(encodeURIComponent).join("/")}`
          );
    }

    const tag = tagNames && {
      slug: tagNames[0],
      // keeps the canonical URL when the tag is the one already shown
      id: tagNames[0] === this.args.tag?.name ? this.args.tag.id : null,
    };

    return NavItem.pathFor(this.listFilter, {
      category,
      tag,
      noSubcategories,
    });
  }

  @action
  navigate(query) {
    DiscourseURL.routeTo(
      this.urlFor(query) ?? getURL(`/filter?q=${encodeURIComponent(query)}`)
    );
  }

  <template>
    <div class="discovery-filter-bar">
      <FilterNavigationBuilder
        @initialInputValue={{this.query}}
        @onChange={{this.navigate}}
        @tips={{this.filterOptions.options}}
      />
    </div>
  </template>
}
