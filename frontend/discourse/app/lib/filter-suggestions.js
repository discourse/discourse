import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

const MAX_RESULTS = 20;

export default class FilterSuggestions {
  /**
   * Main entry point - takes raw input text and available tips, returns suggestions
   * @param {string} text - The full input text from the user
   * @param {Array} tips - Available filter tips from the server
   * @param {Object} context - Additional context (site data, etc.)
   * @returns {Object} { suggestions: Array, activeFilter: string|null }
   */
  static async getSuggestions(text, tips = [], context = {}) {
    const parser = new FilterParser(text);
    const lastSegment = parser.getLastSegment();

    if (!lastSegment.word) {
      return {
        suggestions: this.getTopLevelTips(tips),
        activeFilter: null,
      };
    }

    if (lastSegment.filterName && lastSegment.hasColon) {
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

    // Otherwise, filter the available tips based on what user typed
    return {
      suggestions: this.filterTips(tips, lastSegment.word, lastSegment.prefix),
      activeFilter: null,
    };
  }

  static getTopLevelTips(tips) {
    return tips
      .filter((tip) => tip.priority === 1)
      .sort((a, b) => {
        // First by priority (descending)
        const priorityDiff = (b.priority || 0) - (a.priority || 0);
        if (priorityDiff !== 0) {
          return priorityDiff;
        }
        // Then alphabetically
        return a.name.localeCompare(b.name);
      })
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

/**
 * Parses filter input text into structured segments
 */
class FilterParser {
  constructor(text) {
    this.text = text || "";
    this.segments = this.parse();
  }

  parse() {
    // Split on whitespace, but preserve quoted strings
    const quotedPattern = /"[^"]*"|'[^']*'|[^\s]+/g;
    const words = (this.text.match(quotedPattern) || []).filter(Boolean);
    this.endsWithSpace = this.text.endsWith(" ");
    return words.map((word) => this.parseWord(word));
  }

  parseWord(word) {
    const prefix = this.extractPrefix(word);
    const withoutPrefix = word.substring(prefix.length);
    const colonIndex = withoutPrefix.indexOf(":");

    if (colonIndex > 0) {
      const filterName = withoutPrefix.substring(0, colonIndex);
      const value = withoutPrefix.substring(colonIndex + 1);

      return {
        word,
        prefix,
        filterName,
        value,
        hasColon: true,
      };
    }

    return {
      word,
      prefix,
      filterName: null,
      value: null,
      hasColon: false,
    };
  }

  extractPrefix(word) {
    const match = word.match(/^(-=|=-|-|=)/);
    return match ? match[0] : "";
  }

  getLastSegment() {
    const empty = {
      word: "",
      prefix: "",
      filterName: null,
      value: null,
      hasColon: false,
    };

    if (this.endsWithSpace) {
      return empty;
    }
    return this.segments[this.segments.length - 1] || empty;
  }
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
        `[${this.tip.delimiters.map((d) => this.escapeRegex(d.name)).join("")}]`
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

  escapeRegex(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
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
    const searchLower = this.searchTerm.toLowerCase();

    return categories
      .filter((cat) => {
        const name = cat.name.toLowerCase();
        const slug = cat.slug.toLowerCase();
        return (
          !searchLower ||
          name.includes(searchLower) ||
          slug.includes(searchLower)
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
        // Quote the name if it contains special characters
        const needsQuoting = /[\s&\-()']/.test(tagGroup.name);
        const quotedName = needsQuoting ? `"${tagGroup.name}"` : tagGroup.name;

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

  async getUserSuggestions() {
    try {
      const data = { limit: 10 };
      if (this.searchTerm) {
        data.term = this.searchTerm;
      } else {
        data.last_seen_users = true;
      }

      const response = await ajax("/u/search/users.json", { data });

      let results = response.users.map((user) => ({
        name: this.buildSuggestionName(user.username),
        description: user.name || "",
        term: user.username,
        isSuggestion: true,
      }));

      results = this.prepareDelimiterSuggestions(results);
      return results;
    } catch {
      return [];
    }
  }

  async getGroupSuggestions() {
    try {
      const groupData = { limit: 10 };
      if (this.searchTerm) {
        groupData.term = this.searchTerm;
      }

      const groupResponse = await ajax("/groups/search.json", {
        data: groupData,
      });

      let results = groupResponse.map((group) => ({
        name: this.buildSuggestionName(group.name),
        description: group.full_name || group.name,
        term: group.name,
        isSuggestion: true,
      }));

      results = this.prepareDelimiterSuggestions(results);
      return results;
    } catch {
      return [];
    }
  }

  async getUsernameGroupListSuggestions() {
    const usedTerms = new Set(this.previousValues.map((v) => v.toLowerCase()));
    let suggestions = [];

    // Add special entries (*, nobody, etc.) if no values selected yet
    if (this.tip.extra_entries && usedTerms.size === 0) {
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

    try {
      const userData = { limit: 10 };
      if (this.searchTerm) {
        userData.term = this.searchTerm;
      } else {
        userData.last_seen_users = true;
      }

      const userResponse = await ajax("/u/search/users.json", {
        data: userData,
      });
      const userSuggestions = userResponse.users
        .filter((user) => !usedTerms.has(user.username.toLowerCase()))
        .map((user) => ({
          name: this.buildSuggestionName(user.username),
          description: user.name || "",
          term: user.username,
          isSuggestion: true,
        }));

      suggestions = suggestions.concat(userSuggestions);
    } catch {
      // Continue without user suggestions
    }

    // Add group suggestions
    try {
      const groupData = { limit: 5 };
      if (this.searchTerm) {
        groupData.term = this.searchTerm;
      }

      const groupResponse = await ajax("/groups/search.json", {
        data: groupData,
      });
      const groupSuggestions = groupResponse
        .filter((group) => !usedTerms.has(group.name.toLowerCase()))
        .map((group) => ({
          name: this.buildSuggestionName(group.name),
          description: group.full_name || group.name,
          term: group.name,
          isSuggestion: true,
        }));

      suggestions = suggestions.concat(groupSuggestions);
    } catch {
      // Continue without group suggestions
    }

    suggestions = this.prepareDelimiterSuggestions(suggestions);
    return suggestions
      .sort((a, b) => {
        const searchLower = this.searchTerm?.toLowerCase();
        const aExact = a.term.toLowerCase() === searchLower;
        const bExact = b.term.toLowerCase() === searchLower;

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
      .filter((opt) => {
        if (!this.searchTerm) {
          return true;
        }
        const desc = i18n(`filter.description.days.${opt.key}`);
        return (
          opt.value.includes(this.searchTerm) ||
          desc.toLowerCase().includes(this.searchTerm.toLowerCase())
        );
      })
      .map((opt) => ({
        name: this.buildSuggestionName(opt.value),
        description: i18n(`filter.description.${opt.key}`),
        term: opt.value,
        isSuggestion: true,
      }));
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
      .filter((opt) => !this.searchTerm || opt.value.includes(this.searchTerm))
      .map((opt) => ({
        name: this.buildSuggestionName(opt.value),
        term: opt.value,
        isSuggestion: true,
      }));
  }
}
