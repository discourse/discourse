import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";

const suggestionShortcuts = [
  "in:title",
  "in:pinned",
  "status:open",
  "status:closed",
  "status:public",
  "status:noreplies",
  "order:latest",
  "order:views",
  "order:likes",
  "order:latest_topic",
];

export default class Assistant extends Component {
  @service router;
  @service currentUser;
  @service siteSettings;

  constructor() {
    super(...arguments);

    if (this.currentUser) {
      addSearchSuggestion("in:likes");
      addSearchSuggestion("in:bookmarks");
      addSearchSuggestion("in:mine");
      addSearchSuggestion("in:messages");
      addSearchSuggestion("in:seen");
      addSearchSuggestion("in:tracking");
      addSearchSuggestion("in:unseen");
      addSearchSuggestion("in:watching");
    }

    if (this.siteSettings.tagging_enabled) {
      addSearchSuggestion("in:tagged");
      addSearchSuggestion("in:untagged");
    }
  }

  html(attrs) {
    //const content = [];
    //const { suggestionKeyword, term } = attrs;
    //let prefix;
    //if (suggestionKeyword !== "+") {
    //prefix = term?.split(suggestionKeyword)[0].trim() || "";
    //if (prefix.length) {
    //prefix = `${prefix} `;
    //}
    //}
    //switch (suggestionKeyword) {
    //case "+":
    //attrs.results.forEach((item) => {
    //if (item.additionalTags) {
    //prefix = term?.split(" ").slice(0, -1).join(" ").trim() || "";
    //} else {
    //prefix = term?.split("#")[0].trim() || "";
    //}
    //if (prefix.length) {
    //prefix = `${prefix} `;
    //}
    //content.push(
    //this.attach("search-menu-assistant-item", {
    //prefix,
    //tag: item.tagName,
    //additionalTags: item.additionalTags,
    //category: item.category,
    //slug: term,
    //withInLabel: attrs.withInLabel,
    //isIntersection: true,
    //})
    //);
    //});
    //break;
    //case "#":
    //attrs.results.forEach((item) => {
    //if (item.model) {
    //const fullSlug = item.model.parentCategory
    //? `#${item.model.parentCategory.slug}:${item.model.slug}`
    //: `#${item.model.slug}`;
    //content.push(
    //this.attach("search-menu-assistant-item", {
    //prefix,
    //category: item.model,
    //slug: `${prefix}${fullSlug}`,
    //withInLabel: attrs.withInLabel,
    //})
    //);
    //} else {
    //content.push(
    //this.attach("search-menu-assistant-item", {
    //prefix,
    //tag: item.name,
    //slug: `${prefix}#${item.name}`,
    //withInLabel: attrs.withInLabel,
    //})
    //);
    //}
    //});
    //break;
    //case "@":
    //when only one user matches while in topic
    //quick suggest user search in the topic or globally
    //if (
    //attrs.results.length === 1 &&
    //this.router.currentRouteName.startsWith("topic.")
    //) {
    //const user = attrs.results[0];
    //content.push(
    //this.attach("search-menu-assistant-item", {
    //prefix,
    //user,
    //setTopicContext: true,
    //slug: `${prefix}@${user.username}`,
    //suffix: h(
    //"span.label-suffix",
    //` ${I18n.t("search.in_this_topic")}`
    //),
    //})
    //);
    //content.push(
    //this.attach("search-menu-assistant-item", {
    //extraHint: I18n.t("search.enter_hint"),
    //prefix,
    //user,
    //slug: `${prefix}@${user.username}`,
    //suffix: h(
    //"span.label-suffix",
    //` ${I18n.t("search.in_topics_posts")}`
    //),
    //})
    //);
    //} else {
    //attrs.results.forEach((user) => {
    //content.push(
    //this.attach("search-menu-assistant-item", {
    //prefix,
    //user,
    //slug: `${prefix}@${user.username}`,
    //})
    //);
    //});
    //}
    //break;
    //default:
    //suggestionShortcuts.forEach((item) => {
    //if (item.includes(suggestionKeyword) || !suggestionKeyword) {
    //content.push(
    //this.attach("search-menu-assistant-item", {
    //slug: `${prefix}${item}`,
    //})
    //);
    //}
    //});
    //break;
    //}
    //return content.filter((c, i) => i <= 8);
  }
}

export function addSearchSuggestion(value) {
  if (!suggestionShortcuts.includes(value)) {
    suggestionShortcuts.push(value);
  }
}
