import { ajax } from "discourse/lib/ajax";
import escapeRegExp from "discourse/lib/escape-regexp";
import { removeAccents } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

const MAX_RESULTS = 20;
const SEGMENT_PATTERN = /"[^"]*"|'[^']*'|\S+/g;
const PREFIX_PATTERN = /^(?:-=|=-|-|=)/;
const EMPTY_SEGMENT = Object.freeze({
  word: "",
  prefix: "",
  filterName: null,
  value: null,
});

export default class FilterSuggestions {
  /**
   * Main entry point - takes raw input text and available tips, returns suggestions
   * @param {string} text - The full input text from the user
   * @param {Array} tips - Available filter tips from the server
   * @param {Object} context - Additional context (site data, etc.)
   * @returns {Object} { suggestions: Array, activeFilter: string|null }
   */
  static async getSuggestions(text, tips = [], context = {}) {
    const lastSegment = parseLastSegment(text);

    if (!lastSegment.word) {
      return {
        suggestions: this.getTopLevelTips(tips),
        activeFilter: null,
      };
    }

    if (lastSegment.filterName) {
      const tip = this.findTipForFilter(lastSegment.filterName, tips);

      if (tip?.type) {
        const suggestions = await this.getFilterSuggestionsByType(
          tip,
          lastSegment,
          context
        );

        return {
          suggestions,
          activeFilter: lastSegment.filterName,
        };
      }
    }

    return {
      suggestions: this.filterTips(tips, lastSegment.word, lastSegment.prefix),
      activeFilter: null,
    };
  }

  static getTopLevelTips(tips) {
    return tips
      .filter((tip) => tip.priority === 1)
      .sort((a, b) => a.name.localeCompare(b.name))
      .slice(0, MAX_RESULTS);
  }

  static findTipForFilter(filterName, tips) {
    return tips.find((tip) => {
      const normalize = (str) => (str ? str.replace(/:$/, "") : str);
      return (
        normalize(tip.name) === filterName ||
        normalize(tip.alias) === filterName
      );
    });
  }

  static filterTips(tips, searchTerm, prefix = "") {
    const filtered = [];
    searchTerm = searchTerm.toLowerCase();
    // remove prefix from search term
    if (prefix) {
      searchTerm = searchTerm.replace(prefix, "");
    }

    for (const tip of tips) {
      if (filtered.length >= MAX_RESULTS) {
        break;
      }

      const tipName = tip.name;
      let matches =
        tipName.includes(searchTerm) ||
        (tip.alias && tip.alias.includes(searchTerm));

      if (tipName === searchTerm) {
        matches = false;
      }
      if (!matches) {
        continue;
      }

      if (tip.prefixes) {
        if (prefix) {
          const matchingPrefix = tip.prefixes.find((p) => p.name === prefix);
          if (matchingPrefix) {
            filtered.push({
              ...tip,
              name: `${prefix}${tip.name}`,
              description: matchingPrefix.description || tip.description,
              isSuggestion: true,
            });
          }
        } else {
          filtered.push(tip);
          tip.prefixes.forEach((pfx) => {
            filtered.push({
              ...tip,
              name: `${pfx.name}${tip.name}`,
              description: pfx.description || tip.description,
              isSuggestion: true,
            });
          });
        }
      } else {
        filtered.push({
          ...tip,
          name: `${prefix}${tip.name}`,
          isSuggestion: true,
        });
      }
    }

    return filtered.sort((a, b) => {
      const aStarts = a.name.toLowerCase().startsWith(searchTerm);
      const bStarts = b.name.toLowerCase().startsWith(searchTerm);

      if (aStarts && !bStarts) {
        return -1;
      }
      if (!aStarts && bStarts) {
        return 1;
      }

      return a.name.length - b.name.length;
    });
  }

  static async getFilterSuggestionsByType(tip, segment, context) {
    const suggester = new FilterTypeValueSuggester(tip, segment, context);

    switch (tip.type) {
      case "category":
        return await suggester.getCategorySuggestions();
      case "tag":
        return await suggester.getTagSuggestions();
      case "tag_group":
        return await suggester.getTagGroupSuggestions();
      case "username":
        return await suggester.getUserSuggestions();
      case "group":
        return await suggester.getGroupSuggestions();
      case "username_group_list":
        return await suggester.getUsernameGroupListSuggestions();
      case "date":
        return suggester.getDateSuggestions();
      case "number":
        return suggester.getNumberSuggestions();
      default:
        return [];
    }
  }
}

function parseLastSegment(text) {
  if (!text || text.endsWith(" ")) {
    return EMPTY_SEGMENT;
  }

  const word = text.match(SEGMENT_PATTERN)?.at(-1);

  if (!word) {
    return EMPTY_SEGMENT;
  }

  const prefix = word.match(PREFIX_PATTERN)?.[0] || "";
  const withoutPrefix = word.substring(prefix.length);
  const colonIndex = withoutPrefix.indexOf(":");

  if (colonIndex <= 0) {
    return { word, prefix, filterName: null, value: null };
  }

  return {
    word,
    prefix,
    filterName: withoutPrefix.substring(0, colonIndex),
    value: withoutPrefix.substring(colonIndex + 1),
  };
}

class FilterTypeValueSuggester {
  constructor(tip, segment, context) {
    this.tip = tip;
    this.segment = segment;
    this.context = context;
    this.prefix = segment.prefix || "";
    this.filterName = segment.filterName;

    this.parseMultiValue();
  }

  parseMultiValue() {
    const value = this.segment.value || "";

    if (this.tip.delimiters) {
      const delimiterPattern = new RegExp(
        `[${this.tip.delimiters.map((d) => escapeRegExp(d.name)).join("")}]`
      );

      const parts = value.split(delimiterPattern);
      this.previousValues = parts
        .slice(0, -1)
        .map((p) => p.trim())
        .filter(Boolean);
      this.searchTerm = parts.at(-1).trim();
      this.valuePrefix = value.substring(
        0,
        value.length - this.searchTerm.length
      );
    } else {
      this.previousValues = [];
      this.searchTerm = value;
      this.valuePrefix = "";
    }
  }

  buildSuggestionName(term) {
    return `${this.prefix}${this.filterName}:${this.valuePrefix}${term}`;
  }

  prepareDelimiterSuggestions(results) {
    if (!this.tip.delimiters || this.tip.delimiters.length === 0) {
      return results;
    }
    results.forEach((r) => (r.delimiters = this.tip.delimiters));

    const used = new Set(this.previousValues.map((v) => v.toLowerCase()));
    results = results.filter((r) => !used.has((r.term || "").toLowerCase()));

    const searchLower = (this.searchTerm || "").toLowerCase();
    if (
      searchLower &&
      results.some((r) => (r.term || "").toLowerCase() === searchLower)
    ) {
      this.tip.delimiters.forEach((delimiter) => {
        results.push({
          name: this.buildSuggestionName(`${this.searchTerm}${delimiter.name}`),
          description: delimiter.description,
          isSuggestion: true,
          delimiters: this.tip.delimiters,
        });
      });
    }

    return results;
  }

  async getCategorySuggestions() {
    const categories = this.context.site?.categories || [];
    const normalize = (str) => removeAccents(str.toLowerCase());
    const searchNormalized = normalize(this.searchTerm);

    return categories
      .filter((cat) => {
        const name = normalize(cat.name);
        const slug = normalize(cat.slug);
        return (
          !searchNormalized ||
          name.includes(searchNormalized) ||
          slug.includes(searchNormalized)
        );
      })
      .slice(0, 10)
      .map((cat) => ({
        name: this.buildSuggestionName(cat.slug),
        description: cat.name,
        term: cat.slug,
        category: cat,
        isSuggestion: true,
      }));
  }

  async getTagSuggestions() {
    try {
      const response = await ajax("/tags/filter/search.json", {
        data: { q: this.searchTerm || "", limit: 5 },
      });

      let results = response.results.map((tag) => ({
        name: this.buildSuggestionName(tag.name),
        description: `${tag.count}`,
        term: tag.name,
        isSuggestion: true,
      }));
      results = this.prepareDelimiterSuggestions(results);
      return results;
    } catch {
      return [];
    }
  }

  async getTagGroupSuggestions() {
    try {
      const response = await ajax("/tag_groups/filter/search.json", {
        data: { q: this.searchTerm || "", limit: 10 },
      });

      return response.results.map((tagGroup) => {
        const quotedName = this.quoteIfNeeded(tagGroup.name);

        return {
          name: this.buildSuggestionName(quotedName),
          description: tagGroup.tag_names?.join(", ") || "",
          term: quotedName,
          isSuggestion: true,
        };
      });
    } catch {
      return [];
    }
  }

  quoteIfNeeded(name) {
    if (!/[\s&\-()'"]/.test(name)) {
      return name;
    }

    return name.includes('"') ? `'${name}'` : `"${name}"`;
  }

  async getUserSuggestions() {
    return this.prepareDelimiterSuggestions(await this.#fetchUsers());
  }

  async getGroupSuggestions() {
    return this.prepareDelimiterSuggestions(await this.#fetchGroups());
  }

  async getUsernameGroupListSuggestions() {
    let suggestions = [];

    if (this.tip.extra_entries && this.previousValues.length === 0) {
      suggestions = this.tip.extra_entries
        .filter((entry) => {
          if (!this.searchTerm) {
            return true;
          }

          const searchLower = this.searchTerm.toLowerCase();

          return (
            entry.name.toLowerCase().includes(searchLower) ||
            entry.description.toLowerCase().includes(searchLower)
          );
        })
        .map((entry) => ({
          name: this.buildSuggestionName(entry.name),
          description: entry.description,
          term: entry.name,
          isSuggestion: true,
        }));
    }

    suggestions = this.prepareDelimiterSuggestions(
      suggestions.concat(await this.#fetchUsers(), await this.#fetchGroups(5))
    );

    const searchLower = this.searchTerm?.toLowerCase();

    return suggestions
      .sort((a, b) => {
        const aExact = (a.term || "").toLowerCase() === searchLower;
        const bExact = (b.term || "").toLowerCase() === searchLower;

        if (aExact && !bExact) {
          return -1;
        }

        if (!aExact && bExact) {
          return 1;
        }

        return 0;
      })
      .slice(0, MAX_RESULTS);
  }

  getDateSuggestions() {
    const options = [
      { value: "1", key: "yesterday" },
      { value: "7", key: "last_week" },
      { value: "30", key: "last_month" },
      { value: "365", key: "last_year" },
    ];

    return options
      .map((opt) => ({
        name: this.buildSuggestionName(opt.value),
        description: i18n(`filter.description.${opt.key}`),
        term: opt.value,
        isSuggestion: true,
      }))
      .filter(
        (s) =>
          !this.searchTerm ||
          s.term.includes(this.searchTerm) ||
          s.description.toLowerCase().includes(this.searchTerm.toLowerCase())
      );
  }

  getNumberSuggestions() {
    const options = [
      { value: "0" },
      { value: "1" },
      { value: "5" },
      { value: "10" },
      { value: "20" },
    ];

    return options
      .filter((opt) => Number(opt.value) >= (this.tip.min ?? 0))
      .filter((opt) => !this.searchTerm || opt.value.includes(this.searchTerm))
      .map((opt) => ({
        name: this.buildSuggestionName(opt.value),
        term: opt.value,
        isSuggestion: true,
      }));
  }

  async #fetchGroups(limit = 10) {
    const data = { limit };

    if (this.searchTerm) {
      data.term = this.searchTerm;
    }

    try {
      const response = await ajax("/groups/search.json", { data });

      return response.map((group) => ({
        name: this.buildSuggestionName(group.name),
        description: group.full_name || group.name,
        term: group.name,
        isSuggestion: true,
      }));
    } catch {
      return [];
    }
  }

  async #fetchUsers(limit = 10) {
    const data = { limit };

    if (this.searchTerm) {
      data.term = this.searchTerm;
    } else {
      data.last_seen_users = true;
    }

    try {
      const response = await ajax("/u/search/users.json", { data });

      return response.users.map((user) => ({
        name: this.buildSuggestionName(user.username),
        description: user.name || "",
        term: user.username,
        isSuggestion: true,
      }));
    } catch {
      return [];
    }
  }
}
