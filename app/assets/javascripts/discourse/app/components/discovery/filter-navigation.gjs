import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, later, next } from "@ember/runloop";
import { service } from "@ember/service";
import { and, eq } from "truth-helpers";
import BulkSelectToggle from "discourse/components/bulk-select-toggle";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import element from "discourse/helpers/element";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { resettableTracked } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

const MAX_RESULTS = 20;

export default class DiscoveryFilterNavigation extends Component {
  @service site;

  @tracked copyIcon = "link";
  @tracked copyClass = "btn-default";
  @tracked inputElement = null;
  @tracked showTips = false;
  @tracked searchResults = [];
  @resettableTracked newQueryString = this.args.queryString;

  activeFilter = null;
  searchTimer = null;
  handleBlurTimer = null;

  @tracked _selectedIndex = -1;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.searchTimer);
    cancel(this.handleBlurTimer);

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
    this.blockEnterSubmit(value !== -1);
  }

  get currentItems() {
    return this.filteredTips;
  }

  get currentInputValue() {
    return this.newQueryString || "";
  }

  @bind
  updateQueryString(string) {
    this.newQueryString = string;
  }

  @action
  storeInputElement(inputElement) {
    this.inputElement = inputElement;
  }

  @action
  clearInput() {
    this.newQueryString = "";
    this.args.updateTopicsListQueryParams(this.newQueryString);
    next(() => {
      if (this.inputElement) {
        this.inputElement.dispatchEvent(new Event("input", { bubbles: true }));
        this.inputElement.focus();
      }
    });
  }

  @action
  copyQueryString() {
    this.copyIcon = "check";
    this.copyClass = "btn-default ok";
    navigator.clipboard.writeText(window.location);
    discourseDebounce(this._restoreButton, 3000);
  }

  @bind
  _restoreButton() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }
    this.copyIcon = "link";
    this.copyClass = "btn-default";
  }

  @action
  handleKeydown(event) {
    if (event.key === "Enter" && this._allowEnterSubmit) {
      this.args.updateTopicsListQueryParams(this.newQueryString);
    }
  }

  @action
  blockEnterSubmit(value) {
    this._allowEnterSubmit = !value;
  }

  @action
  setupEventListeners() {
    if (!this.inputElement) {
      throw new Error("DiscoveryFilterNavigation requires an inputElement.");
    }
    this.inputElement.addEventListener("focus", this.handleInputFocus);
    this.inputElement.addEventListener("blur", this.handleInputBlur);
    this.inputElement.addEventListener("keydown", this.handleKeyDownTips);
    this.inputElement.addEventListener("input", this.handleInput);
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
    if (this.inputElement) {
      this.dMenu.trigger = this.inputElement;
      this.dMenu.detachedTrigger = true;
    }
  }

  @action
  handleInput() {
    this.updateResults(this.inputElement.value);
  }

  updateResults(value) {
    this.newQueryString = value;
    this.selectedIndex = -1;

    const words = value.split(/\s+/);
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
    this.showTips = true;
    this.selectedIndex = -1;
    this.dMenu?.show();
  }

  @action
  handleInputBlur() {
    if (this.handleBlurTimer) {
      cancel(this.handleBlurTimer);
    }
    this.handleBlurTimer = later(() => this.hideTipsIfNeeded(), 200);
  }

  hideTipsIfNeeded() {
    this.handleBlurTimer = null;
    if (document.activeElement !== this.inputElement && this.showTips) {
      this.hideTips();
    }
  }

  @action
  handleKeyDownTips(event) {
    if (!this.showTips || this.currentItems.length === 0) {
      return;
    }

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        this.selectedIndex =
          this.selectedIndex === -1
            ? 0
            : (this.selectedIndex + 1) % this.currentItems.length;
        break;
      case "ArrowUp":
        event.preventDefault();
        this.selectedIndex =
          this.selectedIndex === -1
            ? this.currentItems.length - 1
            : (this.selectedIndex - 1 + this.currentItems.length) %
              this.currentItems.length;
        break;
      case "Tab":
        event.preventDefault();
        event.stopPropagation();
        this.selectItem(
          this.currentItems[this.selectedIndex === -1 ? 0 : this.selectedIndex]
        );
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
    this.blockEnterSubmit(false);
  }

  get filteredTips() {
    if (!this.args.tips) {
      return [];
    }

    const words = this.currentInputValue.split(/\s+/);
    const lastWord = words.at(-1).toLowerCase();

    if (this.activeFilter && this.searchResults.length > 0) {
      return this.searchResults;
    }

    const colonIndex = lastWord.indexOf(":");
    const prefix = this.extractPrefix(lastWord) || "";

    if (colonIndex > 0) {
      const filterName = lastWord.substring(prefix.length).split(":")[0];
      const valueText = lastWord.substring(colonIndex + 1);
      const tip = this.args.tips.find((t) => t.name === filterName + ":");
      if (tip?.type && valueText !== undefined) {
        this.handlePlaceholderSearch(filterName, valueText, tip, prefix);
        return this.searchResults.length > 0 ? this.searchResults : [];
      }
    }

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
        tips.push({ ...tip, name: tip.alias });
      }
    });

    return tips.sort((a, b) => {
      const aName = a.name;
      const bName = b.name;
      const aStartsWith = aName.startsWith(lastWord);
      const bStartsWith = bName.startsWith(lastWord);
      if (aStartsWith && !bStartsWith) {
        return -1;
      }
      if (!aStartsWith && bStartsWith) {
        return 1;
      }
      if (aStartsWith && bStartsWith && aName.length !== bName.length) {
        return aName.length - bName.length;
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
      prevTerms =
        lastTerm === "" ? valueText : valueText.slice(0, -lastTerm.length);
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
      results = categories
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
    } else if (type === "username") {
      try {
        const data = { limit: 10 };
        if ((lastTerm || "").length > 0) {
          data.term = lastTerm;
        } else {
          data.last_seen_users = true;
        }
        const response = await ajax("/u/search/users.json", { data });
        results = response.users.map((user) => ({
          name: `${prefix}${filterName}:${prevTerms}${user.username}`,
          description: user.name || "",
          term: user.username,
          isPlaceholderCompletion: true,
        }));
      } catch {
        results = [];
      }
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
      .filter((option) => !lastTerm || option.value.includes(lastTerm))
      .map((option) => ({
        name: `${prefix}${filterName}:${prevTerms}${option.value}`,
        isPlaceholderCompletion: true,
        term: option.value,
      }));
  }

  /* selecting an item ------------------------------------------------------- */
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
      this.updateResults(updatedValue);
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
      this.updateResults(this.currentInputValue);
    });
  }

  updateValue(value) {
    this.newQueryString = value;
    this.args.updateQueryString(value);
  }

  <template>
    {{bodyClass "navigation-filter"}}

    <section class="navigation-container">
      <div class="topic-query-filter">
        {{#if (and this.site.mobileView @canBulkSelect)}}
          <div class="topic-query-filter__bulk-action-btn">
            <BulkSelectToggle @bulkSelectHelper={{@bulkSelectHelper}} />
          </div>
        {{/if}}

        <div class="topic-query-filter__input">
          {{icon "filter" class="topic-query-filter__icon"}}
          <Input
            class="topic-query-filter__filter-term"
            @value={{this.newQueryString}}
            {{on "keydown" this.handleKeydown}}
            @type="text"
            id="queryStringInput"
            autocomplete="off"
            placeholder={{i18n "filter.placeholder"}}
            {{didInsert this.storeInputElement}}
            {{didInsert this.setupEventListeners}}
          />
          {{#if this.newQueryString}}
            <DButton
              @icon="xmark"
              @action={{this.clearInput}}
              @disabled={{unless this.newQueryString "true"}}
              class="topic-query-filter__clear-btn btn-flat"
            />
          {{/if}}
          <PluginOutlet
            @name="below-filter-input"
            @outletArgs={{lazyHash
              updateQueryString=this.updateQueryString
              newQueryString=this.newQueryString
            }}
          />

          <DMenu
            class="filter-navigation__tips"
            @triggerComponent={{element "div"}}
            @onRegisterApi={{this.onRegisterApi}}
            @contentClass="filter-navigation__tips-dropdown"
          >
            <:content>
              {{#if (and this.showTips this.currentItems.length)}}
                <DropdownMenu as |dropdown|>
                  {{#each this.currentItems as |item index|}}
                    <dropdown.item>
                      <DButton
                        class={{concatClass
                          "filter-navigation__tip-button"
                          (if
                            (eq index this.selectedIndex)
                            "filter-navigation__tip-button--selected"
                          )
                        }}
                        @action={{fn this.selectItem item}}
                      >
                        <span class="filter-navigation__tip-name">
                          {{item.name}}
                        </span>
                        {{#if item.description}}
                          <span class="filter-navigation__tip-description">—
                            {{item.description}}</span>
                        {{/if}}
                      </DButton>
                    </dropdown.item>
                  {{/each}}
                </DropdownMenu>
              {{/if}}
            </:content>
          </DMenu>
        </div>
      </div>
    </section>
  </template>
}
