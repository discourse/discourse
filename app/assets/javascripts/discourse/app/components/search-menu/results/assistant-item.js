import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { focusSearchInput } from "discourse/components/search-menu";
import { debounce } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";

const _itemSelectCallbacks = [];
export function addItemSelectCallback(fn) {
  _itemSelectCallbacks.push(fn);
}

export function resetItemSelectCallbacks() {
  _itemSelectCallbacks.length = 0;
}

export default class AssistantItem extends Component {
  @service search;
  @service appEvents;

  icon = this.args.icon || "magnifying-glass";

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

    if (e.key === "Enter") {
      this.itemSelected();
    }

    if (e.key === "ArrowUp" || e.key === "ArrowDown") {
      this.search.handleArrowUpOrDown(e);
    }
  }

  @action
  onClick(e) {
    this.itemSelected();
    e.preventDefault();
    return false;
  }

  @debounce(100)
  itemSelected() {
    let updatedTerm = "";
    if (
      this.args.slug &&
      (this.args.suggestionKeyword || this.args.concatSlug)
    ) {
      updatedTerm = this.prefix.concat(this.args.slug);
    } else {
      updatedTerm = this.prefix.trim();
    }

    const inTopicContext = this.search.searchContext?.type === "topic";
    const searchTopics = !inTopicContext || this.search.activeGlobalSearchTerm;

    if (
      _itemSelectCallbacks.length &&
      !_itemSelectCallbacks.some((fn) =>
        fn({
          updatedTerm,
          searchTermChanged: this.args.searchTermChanged,
          usage: this.args.usage,
        })
      )
    ) {
      // Return early if any callbacks return false
      return;
    }

    this.args.searchTermChanged(updatedTerm, {
      searchTopics,
      ...(inTopicContext &&
        !this.args.searchAllTopics && { setTopicContext: true }),
    });
    focusSearchInput();
  }
}
