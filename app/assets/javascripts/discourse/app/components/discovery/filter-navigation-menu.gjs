import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { cancel, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { i18n } from "discourse-i18n";

const MAX_RESULTS = 20;

export default class FilterNavigationMenu extends Component {
  @service currentUser;
  @service site;

  @tracked selectedIndex = -1;

  searchResults = [];
  activeFilter = null;

  clearSelection() {
    this.selectedIndex = -1;
  }

  get nothingSelected() {
    return this.selectedIndex === -1;
  }

  get filteredTips() {
    if (!this.args.data.tips) {
      return [];
    }

    const words = this.args.data.inputValue.split(/\s+/);
    const lastWord = words.at(-1).toLowerCase();

    if (this.activeFilter && this.searchResults.length > 0) {
      return this.searchResults;
    }

    const colonIndex = lastWord.indexOf(":");
    const prefix = this.#extractPrefix(lastWord) || "";

    if (colonIndex > 0) {
      const filterName = lastWord.substring(prefix.length).split(":")[0];
      const valueText = lastWord.substring(colonIndex + 1);
      const tip = this.args.data.tips.find((t) => t.name === filterName + ":");

      if (tip?.type && valueText !== undefined) {
        this.handleFilterSuggestionSearch(filterName, valueText, tip, prefix);
        return this.searchResults.length > 0 ? this.searchResults : [];
      }
    }

    if (!this.args.data.inputValue || lastWord === "") {
      return this.args.data.tips
        .filter((tip) => tip.priority)
        .sort((a, b) => (b.priority || 0) - (a.priority || 0))
        .slice(0, MAX_RESULTS);
    }

    return this.filteredTipsFromTipData(lastWord, prefix);
  }

  filteredTipsFromTipData(lastWord, prefix) {
    const tips = [];
    this.args.data.tips.forEach((tip) => {
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
        this.#pushPrefixTips(tip, tips, null, prefix);
        if (!prefix) {
          tips.push(tip);
        }
      } else if (tip.alias && tip.alias.indexOf(searchTerm) > -1) {
        this.#pushPrefixTips(tip, tips, tip.alias, prefix);
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

  updateResults() {
    this.clearSelection();

    const words = this.args.data.inputValue.split(/\s+/);
    const lastWord = words.at(-1);
    const colonIndex = lastWord.indexOf(":");

    if (colonIndex > 0) {
      const prefix = this.#extractPrefix(lastWord);
      const filterName = lastWord.substring(
        prefix.length,
        colonIndex + prefix.length
      );
      const valueText = lastWord.substring(colonIndex + 1);

      const tip = this.args.data.tips.find((t) => {
        const tipFilterName = t.name.replace(/^[-=]/, "").split(":")[0];
        return tipFilterName === filterName && t.type;
      });

      if (tip?.type) {
        this.activeFilter = filterName;
        this.handleFilterSuggestionSearch(filterName, valueText, tip, prefix);
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
  handleKeyDownTips(event) {
    if (this.filteredTips.length === 0) {
      return;
    }

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        this.selectedIndex = this.nothingSelected
          ? 0
          : (this.selectedIndex + 1) % this.filteredTips.length;
        break;
      case "ArrowUp":
        event.preventDefault();
        this.selectedIndex = this.nothingSelected
          ? this.filteredTips.length - 1
          : (this.selectedIndex - 1 + this.filteredTips.length) %
            this.filteredTips.length;
        break;
      case "Tab":
        event.preventDefault();
        event.stopPropagation();
        this.selectItem(
          this.filteredTips[this.nothingSelected ? 0 : this.selectedIndex]
        );
        break;
      case "Enter":
        if (this.selectedIndex >= 0) {
          event.preventDefault();
          event.stopPropagation();
          event.stopImmediatePropagation();
          this.selectItem(this.filteredTips[this.selectedIndex]);
        }
        break;
      case "Escape":
        this.hideTips();
        break;
    }
  }

  // Prefixes are modifiers for filters, like -, =, and -=
  #pushPrefixTips(tip, tips, alias = null, currentPrefix = null) {
    if (tip.prefixes && tip.prefixes.length > 0) {
      tip.prefixes.forEach((prefix) => {
        if (currentPrefix && !prefix.name.startsWith(currentPrefix)) {
          return;
        }
        tips.push({
          ...tip,
          name: `${prefix.name}${alias || tip.name}`,
          description: prefix.description || tip.description,
          isSuggestion: true,
        });
      });
    }
  }

  // Prefixes are modifiers for filters, like -, =, and -=
  #extractPrefix(word) {
    const match = word.match(/^(-=|=-|-|=)/);
    return match ? match[0] : "";
  }

  @action
  handleFilterSuggestionSearch(filterName, valueText, tip, prefix = "") {
    this.activeFilter = filterName;
    this.searchTimer = discourseDebounce(
      this,
      this.#performFilterSuggestionSearch,
      filterName,
      valueText,
      tip,
      prefix,
      300
    );
  }

  // item here is a filter tip object either from the initial list of tips
  // from the server or from the suggested results based on the last word.
  //
  // The structure looks like this:
  //
  // {
  //  "name": "category:",
  //  "alias": "categories:",
  //  "description": "Show topics in a specific category",
  //  "priority": 1,
  //  "type": "category",
  //  "delimiters": [
  //      {
  //          "name": ",",
  //          "description": "Show topics in any of the specified categories (comma-separated)"
  //      }
  //  ],
  //  "prefixes": [
  //      {
  //          "name": "-",
  //          "description": "Exclude topics from a specific category"
  //      },
  //      {
  //          "name": "=",
  //          "description": "Show topics only in the parent category, excluding subcategories"
  //      },
  //      {
  //          "name": "-=",
  //          "description": "Exclude topics only from the parent category, not subcategories"
  //      }
  //  ]
  // }
  //
  // c.f. TopicsFilter.option_info on the server-side.
  @action
  selectItem(item) {
    // Split up the string from the text input into words.
    const words = this.args.data.inputValue.split(/\s+/);

    // If we are selecting an item that was suggested based on the initial
    // word selected (e.g. after picking a "category:" the user selects a
    // category from the list), we replace the last word with the selected item.
    if (item.isSuggestion) {
      words[words.length - 1] = item.name;
      let updatedInputQueryString = words.join(" ");
      if (
        !updatedInputQueryString.endsWith(":") &&
        (!item.delimiters || item.delimiters.length < 2)
      ) {
        updatedInputQueryString += " ";
      }
      this.#updateTextInput(updatedInputQueryString);
      this.searchResults = [];
      this.updateResults();
    } else {
      // Otherwise if the user is selecting a filter from the initial tips,
      // we add a colon to the end of it as needed, and fire off the
      // suggestion search based on the filter type.
      const lastWord = words.at(-1);
      const prefix = this.#extractPrefix(lastWord);
      const supportsPrefix = item.prefixes && item.prefixes.length > 0;
      const filterName =
        supportsPrefix && prefix ? `${prefix}${item.name}` : item.name;

      words[words.length - 1] = filterName;
      if (!filterName.endsWith(":") && !item.delimiters?.length) {
        words[words.length - 1] += " ";
      }

      const updatedInputQueryString = words.join(" ");
      this.#updateTextInput(updatedInputQueryString);

      const baseFilterName = item.name.replace(/^[-=]/, "").split(":")[0];
      if (item.type) {
        this.activeFilter = baseFilterName;
        this.handleFilterSuggestionSearch(baseFilterName, "", item, prefix);
      }
    }

    this.clearSelection();

    schedule("afterRender", () => {
      this.args.data.focusInputWithSelection();
      this.updateResults();
    });
  }

  // Updates the actual input element value with the new query string
  // within DiscoveryFilterNavigation.
  #updateTextInput(updatedInputQueryString) {
    this.args.data.onChange(updatedInputQueryString);
  }

  async #performFilterSuggestionSearch(filterName, valueText, tip, prefix) {
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

    switch (type) {
      case "tag":
        results = await this.#getTagSuggestions(
          prefix,
          filterName,
          prevTerms,
          lastTerm
        );
        break;

      case "category":
        results = this.#getCategorySuggestions(
          prefix,
          filterName,
          prevTerms,
          lastTerm
        );
        break;

      case "username":
        results = await this.#getUserSuggestions(
          prefix,
          filterName,
          prevTerms,
          lastTerm
        );
        break;

      case "date":
        results = this.#getDateSuggestions(
          prefix,
          filterName,
          prevTerms,
          lastTerm
        );
        break;

      case "number":
        results = this.#getNumberSuggestions(
          prefix,
          filterName,
          prevTerms,
          lastTerm
        );
        break;
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
            isSuggestion: true,
            delimiters: tip.delimiters,
          });
        });
      }
    }

    this.searchResults = results;

    // We call this from within buildFilteredTips, so in this case we don't need
    // to initiate the rebuild again.
    // if (options.rebuildFilteredTips) {
    //   this.buildFilteredTips();
    // }
  }

  async #getTagSuggestions(prefix, filterName, prevTerms, lastTerm) {
    let results = [];
    try {
      const response = await ajax("/tags/filter/search.json", {
        data: { q: lastTerm || "", limit: 5 },
      });
      results = response.results.map((tag) => ({
        name: `${prefix}${filterName}:${prevTerms}${tag.name}`,
        description: `${tag.count}`,
        isSuggestion: true,
        term: tag.name,
      }));
    } catch {
      results = [];
    }
    return results;
  }

  async #getUserSuggestions(prefix, filterName, prevTerms, lastTerm) {
    let results = [];
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
        isSuggestion: true,
      }));
    } catch {
      results = [];
    }
    return results;
  }

  #getCategorySuggestions(prefix, filterName, prevTerms, lastTerm) {
    const categories = this.site.categories || [];
    return categories
      .filter((category) => {
        const name = category.name.toLowerCase();
        const slug = category.slug.toLowerCase();
        return name.includes(lastTerm) || slug.includes(lastTerm);
      })
      .slice(0, 10)
      .map((category) => ({
        name: `${prefix}${filterName}:${prevTerms}${category.slug}`,
        description: `${category.name}`,
        isSuggestion: true,
        term: category.slug,
      }));
  }

  #getDateSuggestions(prefix, filterName, prevTerms, lastTerm) {
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
        isSuggestion: true,
        term: option.value,
      }));
  }

  #getNumberSuggestions(prefix, filterName, prevTerms, lastTerm) {
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
        isSuggestion: true,
        term: option.value,
      }));
  }

  <template>
    <DropdownMenu as |dropdown|>
      {{#if this.filteredTips.length}}
        {{#each this.filteredTips as |item index|}}
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
      {{/if}}
    </DropdownMenu>
  </template>
}
