import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class FilterSuggestions extends Service {
  @service site;

  async getTagSuggestions(prefix, filterName, prevTerms, lastTerm) {
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

  async getUserSuggestions(prefix, filterName, prevTerms, lastTerm) {
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

  getCategorySuggestions(prefix, filterName, prevTerms, lastTerm) {
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
        isSuggestion: true,
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
        isSuggestion: true,
        term: option.value,
      }));
  }
}
