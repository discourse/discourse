import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class FilterSuggestions {
  static async getFilterSuggestionsByType(
    tip,
    prefix,
    filterName,
    prevTerms,
    lastTerm,
    deps = {}
  ) {
    const suggestions = new FilterSuggestions(
      tip,
      prefix,
      filterName,
      prevTerms,
      lastTerm,
      deps
    );

    switch (tip.type) {
      case "category":
        return await suggestions.getCategorySuggestions();
      case "tag":
        return await suggestions.getTagSuggestions();
      case "username":
        return await suggestions.getUserSuggestions();
      case "date":
        return await suggestions.getDateSuggestions();
      case "number":
        return await suggestions.getNumberSuggestions();
      case "username_group_list":
        return await suggestions.getUsernameGroupListSuggestions();
    }
  }

  constructor(tip, prefix, filterName, prevTerms, lastTerm, deps = {}) {
    this.tip = tip;
    this.prefix = prefix;
    this.filterName = filterName;
    this.prevTerms = prevTerms;
    this.lastTerm = lastTerm;
    this.deps = deps;
  }

  buildSuggestionName(term) {
    return `${this.prefix}${this.filterName}:${this.prevTerms}${term}`;
  }

  async getTagSuggestions() {
    try {
      const response = await ajax("/tags/filter/search.json", {
        data: { q: this.lastTerm || "", limit: 5 },
      });
      return response.results.map((tag) => ({
        name: this.buildSuggestionName(tag.name),
        description: `${tag.count}`,
        isSuggestion: true,
        term: tag.name,
      }));
    } catch {
      return [];
    }
  }

  async getUsernameGroupListSuggestions() {
    let suggestions = [];

    // Parse comma-separated terms - use the last term for searching
    const terms = this.lastTerm ? this.lastTerm.split(",") : [];
    const searchTerm = terms.length > 0 ? terms[terms.length - 1].trim() : "";
    const previousTerms = terms
      .slice(0, -1)
      .map((t) => t.trim())
      .filter((t) => t.length > 0);

    // Create a set of already used terms for duplicate checking
    const usedTerms = new Set(previousTerms.map((t) => t.toLowerCase()));

    // Extra entries are things like wildcards (*) or general terms like "anyone"
    if (this.tip.extra_entries && usedTerms.size === 0) {
      const extraSuggestions = this.tip.extra_entries
        .filter((entry) => {
          // Skip if already used
          if (usedTerms.has(entry.name.toLowerCase())) {
            return false;
          }

          if (!searchTerm) {
            return true;
          }
          return (
            entry.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
            entry.description.toLowerCase().includes(searchTerm.toLowerCase())
          );
        })
        .map((entry) => {
          const termWithCommas =
            previousTerms.length > 0
              ? `${previousTerms.join(",")},${entry.name}`
              : entry.name;
          return {
            name: this.buildSuggestionName(termWithCommas),
            description: entry.description,
            isSuggestion: true,
            term: entry.name,
          };
        });

      suggestions = suggestions.concat(extraSuggestions);
    }

    // Add user suggestions
    try {
      const data = { limit: 10 };
      if (searchTerm.length > 0) {
        data.term = searchTerm;
      } else {
        data.last_seen_users = true;
      }
      const response = await ajax("/u/search/users.json", { data });
      const userSuggestions = response.users
        .filter((user) => !usedTerms.has(user.username.toLowerCase()))
        .map((user) => {
          const termWithCommas =
            previousTerms.length > 0
              ? `${previousTerms.join(",")},${user.username}`
              : user.username;
          return {
            name: this.buildSuggestionName(termWithCommas),
            description: user.name || "",
            term: user.username,
            isSuggestion: true,
          };
        });

      suggestions = suggestions.concat(userSuggestions);
    } catch {
      // skip suggestions in case of rate limit, etc...
      suggestions = [];
    }

    try {
      const data = { limit: 5 };
      if (searchTerm.length > 0) {
        data.term = searchTerm;
      }
      const response = await ajax("/groups/search.json", { data });
      const groupSuggestions = response
        .map((group) => {
          const termWithCommas =
            previousTerms.length > 0
              ? `${previousTerms.join(",")},${group.name}`
              : group.name;
          return {
            name: this.buildSuggestionName(termWithCommas),
            description: group.full_name || group.name,
            term: group.name,
            isSuggestion: true,
          };
        })
        .filter((suggestion) => !usedTerms.has(suggestion.term.toLowerCase()));

      suggestions = suggestions.concat(groupSuggestions);
    } catch {
      // skip suggestions in case of rate limit, etc...
    }

    // Limit total results and prioritize exact matches
    return suggestions
      .sort((a, b) => {
        const aExact = a.term.toLowerCase() === searchTerm?.toLowerCase();
        const bExact = b.term.toLowerCase() === searchTerm?.toLowerCase();
        if (aExact && !bExact) {
          return -1;
        }
        if (!aExact && bExact) {
          return 1;
        }
        return 0;
      })
      .slice(0, 15);
  }

  async getUserSuggestions() {
    try {
      const data = { limit: 10 };
      if ((this.lastTerm || "").length > 0) {
        data.term = this.lastTerm;
      } else {
        data.last_seen_users = true;
      }
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

  async getCategorySuggestions() {
    const categories = this.deps.site?.categories || [];
    return categories
      .filter((category) => {
        const name = category.name.toLowerCase();
        const slug = category.slug.toLowerCase();
        return name.includes(this.lastTerm) || slug.includes(this.lastTerm);
      })
      .slice(0, 10)
      .map((category) => ({
        name: this.buildSuggestionName(category.slug),
        description: `${category.name}`,
        isSuggestion: true,
        term: category.slug,
        category,
      }));
  }

  async getDateSuggestions() {
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
          !this.lastTerm ||
          option.value.includes(this.lastTerm) ||
          description.toLowerCase().includes(this.lastTerm.toLowerCase())
        );
      })
      .map((option) => ({
        name: this.buildSuggestionName(option.value),
        description: i18n(`filter.description.${option.key}`),
        isSuggestion: true,
        term: option.value,
      }));
  }

  async getNumberSuggestions() {
    const numberOptions = [
      { value: "0" },
      { value: "1" },
      { value: "5" },
      { value: "10" },
      { value: "20" },
    ];

    return numberOptions
      .filter(
        (option) => !this.lastTerm || option.value.includes(this.lastTerm)
      )
      .map((option) => ({
        name: this.buildSuggestionName(option.value),
        isSuggestion: true,
        term: option.value,
      }));
  }
}
