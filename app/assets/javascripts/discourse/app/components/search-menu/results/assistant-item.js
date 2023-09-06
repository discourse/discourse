import Component from "@glimmer/component";
import getURL from "discourse-common/lib/get-url";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { debounce } from "discourse-common/utils/decorators";
import {
  focusSearchButton,
  focusSearchInput,
} from "discourse/components/search-menu";

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
  onKeydown(e) {
    // don't capture tab key
    if (e.key === "Tab") {
      return;
    }

    if (e.key === "Escape") {
      focusSearchButton();
      this.args.closeSearchMenu();
      e.preventDefault();
      return false;
    }

    if (e.key === "Enter") {
      this.itemSelected();
    }

    this.search.handleArrowUpOrDown(e);
    e.stopPropagation();
    e.preventDefault();
  }

  @action
  onClick(e) {
    this.itemSelected();
    e.preventDefault();
    return false;
  }

  @debounce(100)
  itemSelected() {
    let updatedValue = "";
    if (this.args.slug) {
      updatedValue = this.prefix.concat(this.args.slug);
    } else {
      updatedValue = this.prefix.trim();
    }
    const inTopicContext = this.search.searchContext?.type === "topic";
    this.args.searchTermChanged(updatedValue, {
      searchTopics: !inTopicContext || this.search.activeGlobalSearchTerm,
      ...(inTopicContext &&
        !this.args.searchAllTopics && { setTopicContext: true }),
    });
    focusSearchInput();
  }
}
