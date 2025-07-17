import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, debounce } from "@ember/runloop";
import { service } from "@ember/service";
import { and, eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";

const MAX_RESULTS = 20;

export default class FilterTips extends Component {
  @service currentUser;
  @service site;

  @tracked showTips = false;
  @tracked currentInputValue = "";
  @tracked searchResults = [];
  @tracked activeFilter = null;
  searchTimer = null;
  @tracked _selectedIndex = -1;

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.searchTimer) {
      cancel(this.searchTimer);
      this.searchTimer = null;
    }
    if (this.inputElement) {
      this.inputElement.removeEventListener("focus", this.handleInputFocus);
      this.inputElement.removeEventListener("blur", this.handleInputBlur);
      this.inputElement.removeEventListener("keydown", this.handleKeyDown);
      this.inputElement.removeEventListener("input", this.handleInput);
    }
  }

  get selectedIndex() {
    return this._selectedIndex;
  }

  set selectedIndex(value) {
    this._selectedIndex = value;
    this.args.blockEnterSubmit(value !== -1);
  }

  get currentItems() {
    return this.filteredTips;
  }

  get filteredTips() {
    if (!this.args.tips) {
      return [];
    }

    const words = this.currentInputValue.split(/\s+/);
    const lastWord = words[words.length - 1].toLowerCase();

    // If we have search results from placeholder search, show those
    if (this.activeFilter && this.searchResults.length > 0) {
      return this.searchResults;
    }

    // Check if we're in the middle of a filter with a value
    const colonIndex = lastWord.indexOf(":");
    if (colonIndex > 0) {
      const prefix = this.extractPrefix(lastWord);
      const filterName = lastWord.substring(
        prefix.length,
        colonIndex + prefix.length
      );
      const valueText = lastWord.substring(colonIndex + prefix.length + 1);

      // Find matching tip
      const tip = this.args.tips.find((t) => {
        const tipFilterName = t.name.replace(/^[-=]/, "").split(":")[0];
        return tipFilterName === filterName;
      });

      // If the tip has a type and we have value text, do placeholder search
      if (tip?.type && valueText !== undefined) {
        this.handlePlaceholderSearch(filterName, valueText, tip.type, prefix);
        return this.searchResults.length > 0 ? this.searchResults : [];
      }
    }

    // Default filtering logic
    if (!this.currentInputValue || lastWord === "") {
      return this.args.tips
        .filter((tip) => tip.priority)
        .sort((a, b) => (b.priority || 0) - (a.priority || 0))
        .slice(0, MAX_RESULTS);
    }

    const tips = [];

    this.args.tips.forEach((tip) => {
      if (tips.length >= MAX_RESULTS) {
        return;
      }
      const tipName = tip.name.replace(/^[-=]/, "");
      const searchTerm = lastWord.replace(/^[-=]/, "");

      // Skip exact matches with colon
      if (searchTerm.endsWith(":") && tipName === searchTerm) {
        return;
      }

      if (tipName.indexOf(searchTerm) > -1) {
        tips.push(tip);
      } else if (tip.alias && tip.alias.indexOf(searchTerm) > -1) {
        tips.push({
          ...tip,
          name: tip.alias,
        });
      }
    });

    return tips.sort((a, b) => {
      const aName = a.name.replace(/^[-=]/, "");
      const bName = b.name.replace(/^[-=]/, "");
      const searchTerm = lastWord.replace(/^[-=]/, "");

      const aStartsWith = aName.startsWith(searchTerm);
      const bStartsWith = bName.startsWith(searchTerm);

      if (aStartsWith && !bStartsWith) {
        return -1;
      }
      if (!aStartsWith && bStartsWith) {
        return 1;
      }

      if (aStartsWith && bStartsWith) {
        if (aName.length !== bName.length) {
          return aName.length - bName.length;
        }
      }

      return aName.localeCompare(bName);
    });
  }

  extractPrefix(word) {
    const match = word.match(/^(-=|=-|-|=)/);
    return match ? match[0] : "";
  }

  @action
  handlePlaceholderSearch(filterName, valueText, type, prefix = "") {
    if (!this.activeFilter || this.activeFilter !== filterName) {
      this.activeFilter = filterName;
    }

    if (this.searchTimer) {
      cancel(this.searchTimer);
    }

    this.searchTimer = debounce(
      this,
      this._performPlaceholderSearch,
      filterName,
      valueText,
      type,
      prefix,
      300
    );
  }

  async _performPlaceholderSearch(filterName, valueText, type, prefix) {
    if (type === "tag") {
      try {
        const response = await ajax("/tags/filter/search.json", {
          data: { q: valueText || "", limit: 5 },
        });
        this.searchResults = response.results.map((tag) => ({
          name: `${prefix}${filterName}:${tag.name}`,
          description: `${tag.count}`,
          isPlaceholderCompletion: true,
        }));
      } catch {
        this.searchResults = [];
      }
    } else if (type === "category") {
      const categories = this.site.categories || [];
      const filtered = categories
        .filter((c) => {
          const name = c.name.toLowerCase();
          const slug = c.slug.toLowerCase();
          const search = (valueText || "").toLowerCase();
          return name.includes(search) || slug.includes(search);
        })
        .slice(0, 10)
        .map((c) => ({
          name: `${prefix}${filterName}:${c.slug}`,
          description: `${c.name}`,
          isPlaceholderCompletion: true,
        }));
      this.searchResults = filtered;
    } else if (type === "username") {
      try {
        const response = await ajax("/u/search/users", {
          data: { term: valueText || "", limit: 10 },
        });
        this.searchResults = response.users.map((user) => ({
          name: `${prefix}${filterName}:${user.username}`,
          isPlaceholderCompletion: true,
        }));
      } catch {
        this.searchResults = [];
      }
    } else if (type === "tag_group") {
      // Handle tag group search if needed
      this.searchResults = [];
    }
  }

  @action
  setupEventListeners(element) {
    this.inputElement = this.args.inputElement;

    if (!this.inputElement) {
      throw new Error(
        "FilterTips requires an inputElement to be passed in the args."
      );
    }
    this.element = element;
    this.inputElement.addEventListener("focus", this.handleInputFocus);
    this.inputElement.addEventListener("blur", this.handleInputBlur);
    this.inputElement.addEventListener("keydown", this.handleKeyDown);
    this.inputElement.addEventListener("input", this.handleInput);
  }

  @action
  handleInput() {
    this.currentInputValue = this.inputElement.value;
    this.updateResults();
  }

  updateResults() {
    this.selectedIndex = -1;

    const words = this.currentInputValue.split(/\s+/);
    const lastWord = words[words.length - 1];
    const colonIndex = lastWord.indexOf(":");

    if (colonIndex > 0) {
      const prefix = this.extractPrefix(lastWord);
      const filterName = lastWord.substring(
        prefix.length,
        colonIndex + prefix.length
      );
      const valueText = lastWord.substring(colonIndex + prefix.length + 1);

      const tip = this.args.tips.find((t) => {
        const tipFilterName = t.name.replace(/^[-=]/, "").split(":")[0];
        return tipFilterName === filterName && t.type;
      });

      if (tip?.type) {
        this.activeFilter = filterName;
        this.handlePlaceholderSearch(filterName, valueText, tip.type, prefix);
      } else {
        this.activeFilter = null;
        this.searchResults = [];
      }
    } else {
      this.activeFilter = null;
      this.searchResults = [];
    }
  }

  @action
  handleInputFocus() {
    this.currentInputValue = this.inputElement.value;
    this.showTips = true;
    this.selectedIndex = -1;
  }

  @action
  handleInputBlur() {
    if (!this.element?.contains(document.activeElement)) {
      this.showTips = false;
      this.activeFilter = null;
      this.searchResults = [];
    }
  }

  @action
  handleKeyDown(event) {
    if (!this.showTips || this.currentItems.length === 0) {
      return;
    }

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        if (this.selectedIndex === -1) {
          this.selectedIndex = 0;
        } else {
          this.selectedIndex =
            (this.selectedIndex + 1) % this.currentItems.length;
        }
        break;
      case "ArrowUp":
        event.preventDefault();
        if (this.selectedIndex === -1) {
          this.selectedIndex = this.currentItems.length - 1;
        } else {
          this.selectedIndex =
            (this.selectedIndex - 1 + this.currentItems.length) %
            this.currentItems.length;
        }
        break;
      case "Tab":
        event.preventDefault();
        event.stopPropagation();
        const indexToUse = this.selectedIndex === -1 ? 0 : this.selectedIndex;
        if (indexToUse < this.currentItems.length) {
          this.selectItem(this.currentItems[indexToUse]);
        }
        break;
      case "Enter":
        if (this.selectedIndex >= 0) {
          event.preventDefault();
          event.stopPropagation();
          event.stopImmediatePropagation();
          this.selectItem(this.currentItems[this.selectedIndex]);
        }
        break;
      case "Escape":
        this.showTips = false;
        this.activeFilter = null;
        this.searchResults = [];
        this.args.blockEnterSubmit(false);
        break;
    }
  }

  @action
  selectItem(item) {
    const words = this.currentInputValue.split(/\s+/);

    if (item.isPlaceholderCompletion) {
      // Replace the current word with the completed value
      words[words.length - 1] = item.name;
      const updatedValue = words.join(" ") + " ";

      this.updateValue(updatedValue);
      this.activeFilter = null;
      this.searchResults = [];
    } else {
      // Handle regular tip selection
      const lastWord = words[words.length - 1];
      const prefix = this.extractPrefix(lastWord);

      // Check if this tip supports prefixes
      const supportsPrefix = item.prefixes && item.prefixes.length > 0;
      const filterName =
        supportsPrefix && prefix ? `${prefix}${item.name}` : item.name;

      words[words.length - 1] = filterName;

      // If the filter ends with colon or has separators, don't add space
      if (!filterName.endsWith(":") && !item.separators?.length) {
        words[words.length - 1] += " ";
      }

      const updatedValue = words.join(" ");
      this.updateValue(updatedValue);

      // Check if we should show placeholder search
      const baseFilterName = item.name.replace(/^[-=]/, "").split(":")[0];

      if (item.type) {
        this.activeFilter = baseFilterName;
        this.handlePlaceholderSearch(baseFilterName, "", item.type, prefix);
      }
    }

    this.selectedIndex = -1;

    const updatedValue = this.inputElement.value;
    this.inputElement.focus();
    this.inputElement.setSelectionRange(
      updatedValue.length,
      updatedValue.length
    );

    this.updateResults();
  }

  updateValue(value) {
    this.currentInputValue = value;
    this.args.onSelectTip(value);
  }

  <template>
    <div class="filter-tips" {{didInsert this.setupEventListeners}}>
      {{#if (and this.showTips this.currentItems.length)}}
        <div class="filter-tips__dropdown">
          {{#each this.currentItems as |item index|}}
            <DButton
              @class={{concatClass
                "filter-tip"
                (if (eq index this.selectedIndex) "selected")
              }}
              @action={{fn this.selectItem item}}
            >
              <span class="filter-name">{{item.name}}</span>
              {{#if item.description}}
                <span class="filter-description">— {{item.description}}</span>
              {{/if}}
            </DButton>
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}
