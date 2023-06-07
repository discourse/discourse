import Component from "@glimmer/component";
import getURL from "discourse-common/lib/get-url";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class AssistantItem extends Component {
  @service search;
  @service appEvents;

  icon = this.args.icon || "search";

  get href() {
    let href = "#";
    if (this.args.category) {
      href = this.args.category.url;

      if (this.args.tags && this.args.isIntersection) {
        href = getURL(`/tag/${this.args.tag}`);
      }
    } else if (
      this.args.tags &&
      this.args.isIntersection &&
      this.args.additionalTags?.length
    ) {
      href = getURL(`/tag/${this.args.tag}`);
    }

    return href;
  }

  get prefix() {
    let prefix = "";
    if (this.args.suggestionKeyword !== "+") {
      prefix =
        this.search.activeGlobalSearchTerm
          ?.split(this.args.suggestionKeyword)[0]
          .trim() || "";
      if (prefix.length) {
        prefix = `${prefix} `;
      }
    } else {
      prefix = this.search.activeGlobalSearchTerm;
    }
    return prefix;
  }

  get tagsSlug() {
    if (!this.args.tag || !this.args.additionalTags) {
      return;
    }

    return `tags:${[this.args.tag, ...this.args.additionalTags].join("+")}`;
  }

  @action
  onKeyup(e) {
    if (e.key === "Escape") {
      document.querySelector("#search-button").focus();
      this.args.closeSearchMenu();
      e.preventDefault();
      return false;
    }
    this.search.handleArrowUpOrDown(e);
  }

  @action
  onClick(e) {
    if (this.search.searchContext?.type === "topic") {
      this.args.setTopicContext();
    }

    let updatedValue = this.prefix.trim();
    if (this.args.slug) {
      updatedValue = updatedValue.concat(this.args.slug);
    }

    this.args.searchTermChanged(updatedValue, {
      searchTopics: this.search.searchContext?.type !== "topic",
    });
    e.preventDefault();
    return false;
  }
}
