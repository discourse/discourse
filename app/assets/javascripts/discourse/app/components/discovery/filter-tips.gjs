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

    if (this.activeFilter && this.searchResults.length > 0) {
      return this.searchResults;
    }

    const colonIndex = lastWord.indexOf(":");
    const endsWithColon = lastWord.endsWith(":");
    if (colonIndex > 0) {
      const filterName = lastWord.substring(0, colonIndex);
      const valueText = lastWord.substring(colonIndex + 1);

      const tip = this.args.tips.find((t) => {
        const tipFilterName = t.name.split(":")[0];
        return tipFilterName === filterName;
      });

      if (tip?.placeholder && valueText !== undefined) {
        this.handlePlaceholderSearch(filterName, valueText, tip.placeholder);
        return this.searchResults.length > 0 ? this.searchResults : [];
      }
    }

    if (!this.currentInputValue || lastWord === "") {
      return this.args.tips
        .filter((tip) => tip.priority)
        .sort((a, b) => (b.priority || 0) - (a.priority || 0))
        .slice(0, MAX_RESULTS);
    }

    return this.args.tips
      .filter((tip) => {
        if (endsWithColon && tip.name === lastWord) {
          return false;
        }
        return tip.name.indexOf(lastWord) > -1;
      })
      .sort((a, b) => {
        const aStartsWith = a.name.startsWith(lastWord);
        const bStartsWith = b.name.startsWith(lastWord);
        if (aStartsWith && !bStartsWith) {
          return -1;
        }
        if (!aStartsWith && bStartsWith) {
          return 1;
        }
        return a.name.localeCompare(b.name);
      })
      .slice(0, MAX_RESULTS);
  }

  @action
  handlePlaceholderSearch(filterName, valueText, placeholder) {
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
      placeholder,
      300
    );
  }

  async _performPlaceholderSearch(filterName, valueText, placeholder) {
    if (placeholder === "tag") {
      try {
        const response = await ajax("/tags/filter/search.json", {
          data: { q: valueText || "", limit: 5 },
        });
        this.searchResults = response.results.map((tag) => ({
          value: `${filterName}:${tag.name}`,
          label: `${filterName}:${tag.name} (${tag.count})`,
          isPlaceholderCompletion: true,
        }));
      } catch {
        this.searchResults = [];
      }
    } else if (placeholder === "category") {
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
          value: `${filterName}:${c.slug}`,
          label: `${filterName}:${c.name}`,
          isPlaceholderCompletion: true,
        }));
      this.searchResults = filtered;
    } else if (placeholder === "username") {
      try {
        const response = await ajax("/u/search/users", {
          data: { term: valueText || "", limit: 10 },
        });
        this.searchResults = response.users.map((user) => ({
          value: `${filterName}:@${user.username}`,
          label: `${filterName}:@${user.username}`,
          isPlaceholderCompletion: true,
        }));
      } catch {
        this.searchResults = [];
      }
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
      const filterName = lastWord.substring(0, colonIndex);
      const valueText = lastWord.substring(colonIndex + 1);

      const tip = this.args.tips.find((t) => {
        // TODO: also add handing for , and + which are a bit special
        const tipFilterName = t.name.split(":")[0];
        return tipFilterName === filterName && t.placeholder;
      });

      if (tip?.placeholder) {
        this.activeFilter = filterName;
        this.handlePlaceholderSearch(filterName, valueText, tip.placeholder);
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
      words[words.length - 1] = item.value;
      const updatedValue = words.join(" ") + " ";

      this.updateValue(updatedValue);
      this.activeFilter = null;
      this.searchResults = [];
    } else {
      const filterName = item.name;
      words[words.length - 1] = filterName;

      if (!filterName.endsWith(":")) {
        words[words.length - 1] += " ";
      }
      const updatedValue = words.join(" ");

      this.updateValue(updatedValue);

      const baseFilterName = filterName.endsWith(":")
        ? filterName.slice(0, -1)
        : filterName;

      const tip = this.args.tips.find((t) => {
        const tipFilterName = t.name.split(":")[0];
        return tipFilterName === baseFilterName;
      });

      if (tip?.placeholder) {
        this.activeFilter = baseFilterName;
        this.handlePlaceholderSearch(baseFilterName, "", tip.placeholder);
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
              {{#if item.isPlaceholderCompletion}}
                <span class="filter-value">{{item.label}}</span>
              {{else}}
                <span class="filter-name">{{item.name}}</span>
                {{#if item.description}}
                  <span class="filter-description">— {{item.description}}</span>
                {{/if}}
              {{/if}}
            </DButton>
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}
