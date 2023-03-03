import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";

export default class InitialOptions extends Component {
  @service search;

  constructor() {
    super(...arguments);

    //if (attrs.term?.match(MODIFIER_REGEXP)) {
    //return this.defaultRow(attrs.term);
    //}

    //const ctx = this.search.searchContext;
    //const content = [];

    //if (attrs.term || ctx) {
    //if (ctx) {
    //const term = attrs.term || "";
    //switch (ctx.type) {
    //case "topic":
    //content.push(
    //this.attach("search-menu-assistant-item", {
    //slug: term,
    //setTopicContext: true,
    //label: [
    //h("span", `${term} `),
    //h("span.label-suffix", I18n.t("search.in_this_topic")),
    //],
    //})
    //);
    //break;

    //case "private_messages":
    //content.push(
    //this.attach("search-menu-assistant-item", {
    //slug: `${term} in:messages`,
    //})
    //);
    //break;

    //case "category":
    //const fullSlug = ctx.category.parentCategory
    //? `#${ctx.category.parentCategory.slug}:${ctx.category.slug}`
    //: `#${ctx.category.slug}`;

    //content.push(
    //this.attach("search-menu-assistant", {
    //term: `${term} ${fullSlug}`,
    //suggestionKeyword: "#",
    //results: [{ model: ctx.category }],
    //withInLabel: true,
    //})
    //);

    //break;
    //case "tag":
    //content.push(
    //this.attach("search-menu-assistant", {
    //term: `${term} #${ctx.name}`,
    //suggestionKeyword: "#",
    //results: [{ name: ctx.name }],
    //withInLabel: true,
    //})
    //);
    //break;
    //case "tagIntersection":
    //let tagTerm;
    //if (ctx.additionalTags) {
    //const tags = [ctx.tagId, ...ctx.additionalTags];
    //tagTerm = `${term} tags:${tags.join("+")}`;
    //} else {
    //tagTerm = `${term} #${ctx.tagId}`;
    //}
    //let suggestionOptions = {
    //tagName: ctx.tagId,
    //additionalTags: ctx.additionalTags,
    //};
    //if (ctx.category) {
    //const categorySlug = ctx.category.parentCategory
    //? `#${ctx.category.parentCategory.slug}:${ctx.category.slug}`
    //: `#${ctx.category.slug}`;
    //suggestionOptions.categoryName = categorySlug;
    //suggestionOptions.category = ctx.category;
    //tagTerm = tagTerm + ` ${categorySlug}`;
    //}

    //content.push(
    //this.attach("search-menu-assistant", {
    //term: tagTerm,
    //suggestionKeyword: "+",
    //results: [suggestionOptions],
    //withInLabel: true,
    //})
    //);
    //break;
    //case "user":
    //content.push(
    //this.attach("search-menu-assistant-item", {
    //slug: `${term} @${ctx.user.username}`,
    //label: [
    //h("span", `${term} `),
    //h(
    //"span.label-suffix",
    //I18n.t("search.in_posts_by", {
    //username: ctx.user.username,
    //})
    //),
    //],
    //})
    //);
    //break;
    //}
    //}

    //if (attrs.term) {
    //content.push(this.defaultRow(attrs.term, { withLabel: true }));
    //}
    //return content;
    //}

    //if (content.length === 0) {
    //content.push(this.attach("random-quick-tip"));

    //if (this.currentUser && this.siteSettings.log_search_queries) {
    //if (this.currentUser.recent_searches?.length) {
    //content.push(this.attach("search-menu-recent-searches"));
    //} else {
    //this.loadRecentSearches();
    //}
    //}
    //}

    //return content;
  }

  defaultRow(term, opts = { withLabel: false }) {
    return this.attach("search-menu-assistant-item", {
      slug: term,
      extraHint: I18n.t("search.enter_hint"),
      label: [
        h("span.keyword", `${term}`),
        opts.withLabel
          ? h("span.label-suffix", I18n.t("search.in_topics_posts"))
          : null,
      ],
    });
  }

  refreshSearchMenuResults() {
    this.scheduleRerender();
  }

  loadRecentSearches() {
    User.loadRecentSearches().then((result) => {
      if (result.success && result.recent_searches?.length) {
        this.currentUser.set(
          "recent_searches",
          Object.assign(result.recent_searches)
        );
        this.scheduleRerender();
      }
    });
  }
}
