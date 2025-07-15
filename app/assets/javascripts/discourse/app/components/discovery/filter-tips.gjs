import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { debounce } from "@ember/runloop";
import { service } from "@ember/service";
import { and, eq, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class FilterTips extends Component {
  @service currentUser;
  @service site;

  @tracked showTips = false;
  @tracked selectedIndex = -1;
  @tracked currentInputValue = "";
  @tracked isSearchingValues = false;
  @tracked searchResults = [];
  @tracked activeFilter = null;

  allFilterTips = [
    {
      filter: "category",
      placeholder: "category/ies to include",
      description: i18n("filters.tips.category"),
      hasValues: true,
      searchType: "category",
    },
    {
      filter: "-category",
      placeholder: "category/ies to exclude",
      description: i18n("filters.tips.exclude_category"),
      hasValues: true,
      searchType: "category",
    },
    {
      filter: "tag",
      placeholder: "tag/s to include",
      description: i18n("filters.tips.tag"),
      hasValues: true,
      searchType: "tag",
    },
    {
      filter: "-tag",
      placeholder: "tag/s to exclude",
      description: i18n("filters.tips.exclude_tag"),
      hasValues: true,
      searchType: "tag",
    },
    {
      filter: "status",
      placeholder: "status value",
      description: i18n("filters.tips.status"),
      values: ["open", "closed", "archived", "listed", "unlisted", "public"],
      hasValues: true,
    },
    {
      filter: "in",
      placeholder: "location",
      description: i18n("filters.tips.in"),
      values: [
        "bookmarked",
        "posted",
        "watching",
        "tracking",
        "muted",
        "pinned",
      ],
      hasValues: true,
    },
    {
      filter: "created-after",
      placeholder: "days ago or YYYY-MM-DD",
      description: i18n("filters.tips.created_after"),
    },
    {
      filter: "created-before",
      placeholder: "days ago or YYYY-MM-DD",
      description: i18n("filters.tips.created_before"),
    },
    {
      filter: "activity-after",
      placeholder: "days ago or YYYY-MM-DD",
      description: i18n("filters.tips.activity_after"),
    },
    {
      filter: "activity-before",
      placeholder: "days ago or YYYY-MM-DD",
      description: i18n("filters.tips.activity_before"),
    },
    {
      filter: "likes-min",
      placeholder: "minimum likes",
      description: i18n("filters.tips.likes_min"),
    },
    {
      filter: "likes-max",
      placeholder: "maximum likes",
      description: i18n("filters.tips.likes_max"),
    },
    {
      filter: "posts-min",
      placeholder: "minimum posts",
      description: i18n("filters.tips.posts_min"),
    },
    {
      filter: "posts-max",
      placeholder: "maximum posts",
      description: i18n("filters.tips.posts_max"),
    },
    {
      filter: "posters-min",
      placeholder: "minimum posters",
      description: i18n("filters.tips.posters_min"),
    },
    {
      filter: "views-min",
      placeholder: "minimum views",
      description: i18n("filters.tips.views_min"),
    },
    {
      filter: "created-by",
      placeholder: "@username",
      description: i18n("filters.tips.created_by"),
      hasValues: true,
      searchType: "user",
    },
    {
      filter: "order",
      placeholder: "sort order",
      description: i18n("filters.tips.order"),
      values: ["activity", "created", "likes", "views", "latest-post", "title"],
      hasValues: true,
    },
  ];

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.inputElement) {
      this.inputElement.removeEventListener("focus", this.handleInputFocus);
      this.inputElement.removeEventListener("blur", this.handleInputBlur);
      this.inputElement.removeEventListener("keydown", this.handleKeyDown);
      this.inputElement.removeEventListener("input", this.handleInput);
    }
  }

  get currentItems() {
    if (this.isSearchingValues) {
      return this.searchResults;
    }
    return this.filteredTips;
  }

  get filteredTips() {
    if (!this.currentInputValue) {
      return this.allFilterTips.slice(0, 8);
    }

    const words = this.currentInputValue.split(/\s+/);
    const lastWord = words[words.length - 1].toLowerCase();

    // Check if we're in value entry mode
    const colonIndex = lastWord.indexOf(":");
    if (colonIndex !== -1) {
      const filterName = lastWord.substring(0, colonIndex);
      const valueText = lastWord.substring(colonIndex + 1);
      const filter = this.allFilterTips.find(
        (tip) => tip.filter === filterName
      );

      if (filter) {
        this.activeFilter = filter;
        this.isSearchingValues = true;

        if (filter.searchType) {
          this.performValueSearch(filter.searchType, valueText);
          return [];
        } else if (filter.values) {
          const filtered = filter.values
            .filter((v) => v.toLowerCase().includes(valueText.toLowerCase()))
            .map((v) => ({ value: v, label: v }));
          this.searchResults = filtered;
          return [];
        }
      }
    }

    // Regular filter search
    this.isSearchingValues = false;
    this.activeFilter = null;
    return this.allFilterTips
      .filter((tip) => tip.filter.toLowerCase().startsWith(lastWord))
      .slice(0, 8);
  }

  @action
  performValueSearch(searchType, query) {
    debounce(this, this._performValueSearch, searchType, query, 300);
  }

  async _performValueSearch(searchType, query) {
    if (searchType === "tag") {
      try {
        const response = await ajax("/tags/filter/search", {
          data: { q: query || "", limit: 20 },
        });
        this.searchResults = response.results.map((tag) => ({
          value: tag.name,
          label: `${tag.name} (${tag.count})`,
        }));
      } catch {
        this.searchResults = [];
      }
    } else if (searchType === "category") {
      const categories = this.site.categories || [];
      const filtered = categories
        .filter((c) => {
          const name = c.name.toLowerCase();
          const slug = c.slug.toLowerCase();
          const search = (query || "").toLowerCase();
          return name.includes(search) || slug.includes(search);
        })
        .slice(0, 20)
        .map((c) => ({
          value: c.slug,
          label: c.name,
        }));
      this.searchResults = filtered;
    } else if (searchType === "user") {
      try {
        const response = await ajax("/u/search/users", {
          data: { term: query || "", limit: 20 },
        });
        this.searchResults = response.users.map((user) => ({
          value: `@${user.username}`,
          label: `@${user.username}`,
        }));
      } catch {
        this.searchResults = [];
      }
    }
  }

  @action
  setupEventListeners(element) {
    this.element = element;
    this.inputElement = document.querySelector("#queryStringInput");
    if (this.inputElement) {
      this.inputElement.addEventListener("focus", this.handleInputFocus);
      this.inputElement.addEventListener("blur", this.handleInputBlur);
      this.inputElement.addEventListener("keydown", this.handleKeyDown);
      this.inputElement.addEventListener("input", this.handleInput);
    }
  }

  @action
  handleInput(event) {
    this.currentInputValue = event.target.value;
    // Reset selection when input changes
    this.selectedIndex = -1;
  }

  @action
  handleInputFocus(event) {
    this.currentInputValue = event.target.value;
    this.showTips = true;
    this.selectedIndex = -1;
  }

  @action
  handleInputBlur() {
    setTimeout(() => {
      if (!this.element?.contains(document.activeElement)) {
        this.showTips = false;
        this.isSearchingValues = false;
        this.activeFilter = null;
      }
    }, 200);
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
        // If nothing selected, use first item if available
        const indexToUse = this.selectedIndex === -1 ? 0 : this.selectedIndex;
        if (indexToUse < this.currentItems.length) {
          if (this.isSearchingValues) {
            this.selectValue(this.currentItems[indexToUse]);
          } else {
            this.selectTip(this.currentItems[indexToUse]);
          }
        }
        break;
      case "Enter":
        // Only handle if something is selected
        if (this.selectedIndex >= 0) {
          event.preventDefault();
          event.stopPropagation();
          event.stopImmediatePropagation();
          if (this.isSearchingValues) {
            this.selectValue(this.currentItems[this.selectedIndex]);
          } else {
            this.selectTip(this.currentItems[this.selectedIndex]);
          }
        }
        break;
      case "Escape":
        this.showTips = false;
        this.isSearchingValues = false;
        break;
    }
  }

  @action
  selectTip(tip) {
    const words = this.currentInputValue.split(/\s+/);
    words[words.length - 1] = tip.filter + ":";
    const updatedValue = words.join(" ");

    this.args.onSelectTip(updatedValue);
    this.selectedIndex = -1;
    this.isSearchingValues = true;
    this.activeFilter = tip;

    if (tip.searchType) {
      this.performValueSearch(tip.searchType, "");
    } else if (tip.values) {
      this.searchResults = tip.values.map((v) => ({ value: v, label: v }));
    }

    if (this.inputElement) {
      this.inputElement.focus();
      this.inputElement.setSelectionRange(
        updatedValue.length,
        updatedValue.length
      );
    }
  }

  @action
  selectValue(item) {
    const words = this.currentInputValue.split(/\s+/);
    const lastWord = words[words.length - 1];
    const colonIndex = lastWord.indexOf(":");
    const filterName = lastWord.substring(0, colonIndex);

    words[words.length - 1] = `${filterName}:${item.value}`;
    const updatedValue = words.join(" ") + " ";

    this.args.onSelectTip(updatedValue);
    this.showTips = false;
    this.isSearchingValues = false;
    this.activeFilter = null;

    if (this.inputElement) {
      this.inputElement.focus();
      this.inputElement.setSelectionRange(
        updatedValue.length,
        updatedValue.length
      );
    }
  }

  <template>
    <div class="filter-tips" {{didInsert this.setupEventListeners}}>
      {{#if
        (and
          this.showTips (or this.filteredTips.length this.searchResults.length)
        )
      }}
        <div class="filter-tips__dropdown">
          {{#if this.isSearchingValues}}
            {{#each this.searchResults as |item index|}}
              <DButton
                @class={{concatClass
                  "filter-tip"
                  (if (eq index this.selectedIndex) "selected")
                }}
                @action={{fn this.selectValue item}}
              >
                {{item.label}}
              </DButton>
            {{/each}}
          {{else}}
            {{#each this.filteredTips as |tip index|}}
              <DButton
                @class={{concatClass
                  "filter-tip"
                  (if (eq index this.selectedIndex) "selected")
                }}
                @action={{fn this.selectTip tip}}
              >
                <span class="filter-name">{{tip.filter}}:</span>
                <span class="filter-placeholder">{{tip.placeholder}}</span>
              </DButton>
            {{/each}}
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
