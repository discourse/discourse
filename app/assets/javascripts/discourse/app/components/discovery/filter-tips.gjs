import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, later, next } from "@ember/runloop";
import { service } from "@ember/service";
import { and, eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

const MAX_RESULTS = 20;

export default class FilterTips extends Component {
  @service currentUser;
  @service site;

  @tracked showTips = false;
  @tracked currentInputValue = "";
  @tracked searchResults = [];

  dMenu = null;

  activeFilter = null;
  searchTimer = null;
  handleBlurTimer = null;

  @tracked _selectedIndex = -1;

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.searchTimer) {
      cancel(this.searchTimer);
      this.searchTimer = null;
    }

    if (this.handleBlurTimer) {
      cancel(this.handleBlurTimer);
      this.handleBlurTimer = null;
    }
    if (this.inputElement) {
      this.inputElement.removeEventListener("focus", this.handleInputFocus);
      this.inputElement.removeEventListener("blur", this.handleInputBlur);
      this.inputElement.removeEventListener("keydown", this.handleKeyDown);
      this.inputElement.removeEventListener("input", this.handleInput);
    }

    this.dMenu?.destroy();
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
    const lastWord = words.at(-1).toLowerCase();

    // If we have search results from placeholder search, show those
    if (this.activeFilter && this.searchResults.length > 0) {
      return this.searchResults;
    }

    // Check if we're in the middle of a filter with a value
    const colonIndex = lastWord.indexOf(":");
    const prefix = this.extractPrefix(lastWord) || "";
    if (colonIndex > 0) {
      const filterName = lastWord.substring(prefix.length).split(":")[0];
      const valueText = lastWord.substring(colonIndex + 1);

      // Find matching tip
      const tip = this.args.tips.find((t) => {
        return t.name === filterName + ":";
      });

      // If the tip has a type and we have value text, do placeholder search
      if (tip?.type && valueText !== undefined) {
        this.handlePlaceholderSearch(filterName, valueText, tip, prefix);
        return this.searchResults.length > 0 ? this.searchResults : [];
      }
    }

    // This handles blank, the default state when nothing is typed
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
      const tipName = tip.name;
      const searchTerm = lastWord.substring(prefix.length);

      // Skip exact matches with colon
      if (searchTerm.endsWith(":") && tipName === searchTerm) {
        return;
      }

      const prefixMatch =
        searchTerm === "" &&
        prefix &&
        tipName.prefixes &&
        tipName.prefixes.find((p) => p.name === prefix);

      if (prefixMatch || tipName.indexOf(searchTerm) > -1) {
        this.pushPrefixTips(tip, tips, null, prefix);
        if (!prefix) {
          tips.push(tip);
        }
      } else if (tip.alias && tip.alias.indexOf(searchTerm) > -1) {
        this.pushPrefixTips(tip, tips, tip.alias, prefix);
        tips.push({
          ...tip,
          name: tip.alias,
        });
      }
    });

    return tips.sort((a, b) => {
      const aName = a.name;
      const bName = b.name;
      const searchTerm = lastWord;

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

  pushPrefixTips(tip, tips, alias = null, currentPrefix = null) {
    if (tip.prefixes && tip.prefixes.length > 0) {
      tip.prefixes.forEach((prefix) => {
        if (currentPrefix && !prefix.name.startsWith(currentPrefix)) {
          return;
        }
        tips.push({
          ...tip,
          name: `${prefix.name}${alias || tip.name}`,
          description: prefix.description || tip.description,
          isPlaceholderCompletion: true,
        });
      });
    }
  }

  extractPrefix(word) {
    const match = word.match(/^(-=|=-|-|=)/);
    return match ? match[0] : "";
  }

  @action
  handlePlaceholderSearch(filterName, valueText, tip, prefix = "") {
    this.activeFilter = filterName;

    if (this.searchTimer) {
      cancel(this.searchTimer);
    }

    this.searchTimer = discourseDebounce(
      this,
      this._performPlaceholderSearch,
      filterName,
      valueText,
      tip,
      prefix,
      300
    );
  }

  async _performPlaceholderSearch(filterName, valueText, tip, prefix) {
    const type = tip.type;
    let lastTerm = valueText;
    let results = [];

    let prevTerms = "";
    let splitTerms;

    if (tip.delimiters) {
      const delimiters = tip.delimiters.map((s) => s.name);
      splitTerms = lastTerm.split(new RegExp(`[${delimiters.join("")}]`));
      lastTerm = splitTerms[splitTerms.length - 1];
      if (lastTerm === "") {
        prevTerms = valueText;
      } else {
        prevTerms = valueText.slice(0, -lastTerm.length);
      }
    }

    lastTerm = (lastTerm || "").toLowerCase().trim();

    if (type === "tag") {
      try {
        const response = await ajax("/tags/filter/search.json", {
          data: { q: lastTerm || "", limit: 5 },
        });
        results = response.results.map((tag) => ({
          name: `${prefix}${filterName}:${prevTerms}${tag.name}`,
          description: `${tag.count}`,
          isPlaceholderCompletion: true,
          term: tag.name,
        }));
      } catch {
        results = [];
      }
    } else if (type === "category") {
      const categories = this.site.categories || [];
      const filtered = categories
        .filter((c) => {
          const name = c.name.toLowerCase();
          const slug = c.slug.toLowerCase();
          return name.includes(lastTerm) || slug.includes(lastTerm);
        })
        .slice(0, 10)
        .map((c) => ({
          name: `${prefix}${filterName}:${prevTerms}${c.slug}`,
          description: `${c.name}`,
          isPlaceholderCompletion: true,
          term: c.slug,
        }));
      results = filtered;
    } else if (type === "username") {
      try {
        const data = {
          limit: 10,
        };

        if ((lastTerm || "").length > 0) {
          data.term = lastTerm;
        } else {
          data.last_seen_users = true;
        }
        const response = await ajax("/u/search/users.json", {
          data,
        });
        results = response.users.map((user) => ({
          name: `${prefix}${filterName}:${prevTerms}${user.username}`,
          description: user.name || "",
          term: user.username,
          isPlaceholderCompletion: true,
        }));
      } catch {
        results = [];
      }
    } else if (type === "tag_group") {
      // Handle tag group search if needed
      results = [];
    } else if (type === "date") {
      results = this.getDateSuggestions(
        prefix,
        filterName,
        prevTerms,
        lastTerm
      );
    } else if (type === "number") {
      results = this.getNumberSuggestions(
        prefix,
        filterName,
        prevTerms,
        lastTerm
      );
    }

    // special handling for exact matches
    if (tip.delimiters) {
      let lastMatches = false;

      results = results.map((r) => {
        r.delimiters = tip.delimiters;
        return r;
      });

      results = results.filter((r) => {
        lastMatches ||= lastTerm === r.term;
        if (splitTerms.includes(r.term)) {
          return false;
        }
        return true;
      });

      if (lastMatches) {
        tip.delimiters.forEach((delimiter) => {
          results.push({
            name: `${prefix}${filterName}:${prevTerms}${lastTerm}${delimiter.name}`,
            description: delimiter.description,
            isPlaceholderCompletion: true,
            delimiters: tip.delimiters,
          });
        });
      }
    }

    this.searchResults = results;
  }

  getDateSuggestions(prefix, filterName, prevTerms, lastTerm) {
    const dateOptions = [
      { value: "1", key: "yesterday" },
      { value: "7", key: "last_week" },
      { value: "30", key: "last_month" },
      { value: "365", key: "last_year" },
    ];

    return dateOptions
      .filter((option) => {
        const description = i18n(`filter.description.days.${option.key}`);
        return (
          !lastTerm ||
          option.value.includes(lastTerm) ||
          description.toLowerCase().includes(lastTerm.toLowerCase())
        );
      })
      .map((option) => ({
        name: `${prefix}${filterName}:${prevTerms}${option.value}`,
        description: i18n(`filter.description.${option.key}`),
        isPlaceholderCompletion: true,
        term: option.value,
      }));
  }

  getNumberSuggestions(prefix, filterName, prevTerms, lastTerm) {
    const numberOptions = [
      { value: "0" },
      { value: "1" },
      { value: "5" },
      { value: "10" },
      { value: "20" },
    ];

    return numberOptions
      .filter((option) => {
        return !lastTerm || option.value.includes(lastTerm);
      })
      .map((option) => ({
        name: `${prefix}${filterName}:${prevTerms}${option.value}`,
        isPlaceholderCompletion: true,
        term: option.value,
      }));
  }

  @action
  setupEventListeners() {
    this.inputElement = this.args.inputElement;

    if (!this.inputElement) {
      throw new Error(
        "FilterTips requires an inputElement to be passed in the args."
      );
    }

    this.inputElement.addEventListener("focus", this.handleInputFocus);
    this.inputElement.addEventListener("blur", this.handleInputBlur);
    this.inputElement.addEventListener("keydown", this.handleKeyDown);
    this.inputElement.addEventListener("input", this.handleInput);
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
    if (this.args.inputElement) {
      this.dMenu.trigger = this.args.inputElement;
      this.dMenu.detachedTrigger = true;
    }
  }

  @action
  handleInput() {
    this.currentInputValue = this.inputElement.value;
    this.updateResults();
  }

  updateResults() {
    this.selectedIndex = -1;

    const words = this.currentInputValue.split(/\s+/);
    const lastWord = words.at(-1);
    const colonIndex = lastWord.indexOf(":");

    if (colonIndex > 0) {
      const prefix = this.extractPrefix(lastWord);
      const filterName = lastWord.substring(
        prefix.length,
        colonIndex + prefix.length
      );
      const valueText = lastWord.substring(colonIndex + 1);

      const tip = this.args.tips.find((t) => {
        const tipFilterName = t.name.replace(/^[-=]/, "").split(":")[0];
        return tipFilterName === filterName && t.type;
      });

      if (tip?.type) {
        this.activeFilter = filterName;
        this.handlePlaceholderSearch(filterName, valueText, tip, prefix);
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
    this.dMenu?.show();
  }

  @action
  handleInputBlur() {
    if (this.handleBlurTimer) {
      cancel(this.handleBlurTimer);
    }
    // delay this cause we need to handle click events on tips
    this.handleBlurTimer = later(() => {
      this.hideTipsIfNeeded();
    }, 200);
  }

  hideTipsIfNeeded() {
    this.handleBlurTimer = null;
    if (document.activeElement !== this.inputElement && this.showTips) {
      this.hideTips();
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
        this.hideTips();
        break;
    }
  }

  hideTips() {
    this.showTips = false;
    this.dMenu?.close();
    this.args.blockEnterSubmit(false);
  }

  @action
  selectItem(item) {
    const words = this.currentInputValue.split(/\s+/);

    if (item.isPlaceholderCompletion) {
      words[words.length - 1] = item.name;
      let updatedValue = words.join(" ");

      if (
        !updatedValue.endsWith(":") &&
        (!item.delimiters || item.delimiters.length < 2)
      ) {
        updatedValue += " ";
      }

      this.updateValue(updatedValue);
      this.searchResults = [];
      this.updateResults();
    } else {
      const lastWord = words.at(-1);
      const prefix = this.extractPrefix(lastWord);

      const supportsPrefix = item.prefixes && item.prefixes.length > 0;
      const filterName =
        supportsPrefix && prefix ? `${prefix}${item.name}` : item.name;

      words[words.length - 1] = filterName;

      if (!filterName.endsWith(":") && !item.delimiters?.length) {
        words[words.length - 1] += " ";
      }

      const updatedValue = words.join(" ");
      this.updateValue(updatedValue);

      const baseFilterName = item.name.replace(/^[-=]/, "").split(":")[0];

      if (item.type) {
        this.activeFilter = baseFilterName;
        this.handlePlaceholderSearch(baseFilterName, "", item, prefix);
      }
    }

    this.selectedIndex = -1;

    next(() => {
      this.inputElement.focus();
      this.inputElement.setSelectionRange(
        this.currentInputValue.length,
        this.currentInputValue.length
      );
      this.updateResults();
    });
  }

  updateValue(value) {
    this.currentInputValue = value;
    this.args.onSelectTip(value);
  }

  <template>
    <DMenu
      class="filter-tips"
      @triggerComponent={{element "div"}}
      @onRegisterApi={{this.onRegisterApi}}
      @contentClass="filter-tips__dropdown"
      {{didInsert this.setupEventListeners}}
    >
      <:trigger></:trigger>
      <:content>
        {{#if (and this.showTips this.currentItems.length)}}
          <DropdownMenu as |dropdown|>
            {{#each this.currentItems as |item index|}}
              <dropdown.item>
                <DButton
                  class={{concatClass
                    "filter-tip__button"
                    (if (eq index this.selectedIndex) "filter-tip__selected")
                  }}
                  @action={{fn this.selectItem item}}
                >
                  <span class="filter-tip__name">{{item.name}}</span>
                  {{#if item.description}}
                    <span class="filter-tip__description">—
                      {{item.description}}</span>
                  {{/if}}
                </DButton>
              </dropdown.item>
            {{/each}}
          </DropdownMenu>
        {{/if}}
      </:content>
    </DMenu>
  </template>
}
