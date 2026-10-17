import Component from "@glimmer/component";
import { service } from "@ember/service";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class NavigationItem extends Component {
  @service currentUser;
  @service siteSettings;

  get filterType() {
    return filterTypeForMode(this.args.filterMode);
  }

  get active() {
    if (this.args.content?.active !== undefined) {
      return this.args.content?.active;
    }
    return this.args.content?.filterType === this.filterType;
  }

  get isHidden() {
    return (
      !this.active &&
      this.currentUser &&
      !this.currentUser.unified_new_enabled &&
      this.currentUser.trust_level > 0 &&
      (this.args.content?.name === "new" ||
        this.args.content?.name === "unread") &&
      this.args.content?.count < 1
    );
  }

  get hrefLink() {
    const content = this.args.content;

    let [href, searchParams] = content.get("href")?.split("?") || [];

    let urlSearchParams = new URLSearchParams(searchParams);
    let addParamsEvenIfEmpty = false;

    // Include the category id if the option is present
    if (content.get("includeCategoryId")) {
      let categoryId = content.get("category.id");
      if (categoryId) {
        urlSearchParams.set("category_id", categoryId);
      }
    }

    // To reset the "filter" sticky param, at least one query param is needed.
    // If no query param is present, add an empty one to ensure a ? is
    // appended to the URL.
    if (content.currentRouteQueryParams) {
      if (content.currentRouteQueryParams.filter) {
        addParamsEvenIfEmpty = true;
      }

      if (content.currentRouteQueryParams.f) {
        urlSearchParams.set("f", content.currentRouteQueryParams.f);
      }
    }

    if (
      this.siteSettings.desktop_category_page_style ===
        "categories_and_latest_topics_created_date" &&
      urlSearchParams.get("order") == null
    ) {
      urlSearchParams.set("order", "created");
    }

    const queryString = urlSearchParams.toString();
    if (addParamsEvenIfEmpty || (queryString && href)) {
      href = (href || "") + `?${queryString}`;
    }
    return href;
  }

  <template>
    <li
      class={{dConcatClass
        (if this.active "active")
        (if @content.hasIcon "has-icon")
        @content.classNames
        (if this.isHidden "hidden")
        @content.name
      }}
      title={{@content.title}}
      ...attributes
    >
      <a
        aria-current={{if this.active "page"}}
        class={{if this.active "active"}}
        href={{this.hrefLink}}
      >
        {{#if this.hasIcon}}
          <span class={{@content.name}}></span>
        {{/if}}
        {{@content.displayName}}
      </a>
    </li>
  </template>
}
