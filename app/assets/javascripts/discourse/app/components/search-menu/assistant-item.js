import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";

export default class AssistantItem extends Component {
  constructor() {
    super(...arguments);

    //const prefix = attrs.prefix?.trim();
    //const attributes = {};
    //attributes.href = "#";

    //let content = [
    //h(
    //"span",
    //{ attributes: { "aria-label": I18n.t("search.title") } },
    //iconNode(attrs.icon || "search")
    //),
    //];

    //if (prefix) {
    //content.push(h("span.search-item-prefix", `${prefix} `));
    //}

    //if (attrs.withInLabel) {
    //content.push(h("span.label-suffix", `${I18n.t("search.in")} `));
    //}

    //if (attrs.category) {
    //attributes.href = attrs.category.url;

    //content.push(
    //this.attach("category-link", {
    //category: attrs.category,
    //allowUncategorized: true,
    //recursive: true,
    //link: false,
    //})
    //);

    //category and tag combination
    //if (attrs.tag && attrs.isIntersection) {
    //attributes.href = getURL(`/tag/${attrs.tag}`);
    //content.push(h("span.search-item-tag", [iconNode("tag"), attrs.tag]));
    //}
    //} else if (attrs.tag) {
    //if (attrs.isIntersection && attrs.additionalTags?.length) {
    //const tags = [attrs.tag, ...attrs.additionalTags];
    //content.push(h("span.search-item-tag", `tags:${tags.join("+")}`));
    //} else {
    //attributes.href = getURL(`/tag/${attrs.tag}`);
    //content.push(h("span.search-item-tag", [iconNode("tag"), attrs.tag]));
    //}
    //} else if (attrs.user) {
    //const userResult = [
    //avatarImg("small", {
    //template: attrs.user.avatar_template,
    //username: attrs.user.username,
    //}),
    //h("span.username", formatUsername(attrs.user.username)),
    //attrs.suffix,
    //];
    //content.push(h("span.search-item-user", userResult));
    //} else {
    //content.push(h("span.search-item-slug", attrs.label || attrs.slug));
    //}
    //if (attrs.extraHint) {
    //content.push(h("span.extra-hint", attrs.extraHint));
    //}
    //return h("a.widget-link.search-link", { attributes }, content);
  }

  click(e) {
    const searchInput = document.querySelector("#search-term");
    searchInput.value = this.attrs.slug;
    searchInput.focus();
    this.sendWidgetAction("triggerAutocomplete", {
      value: this.attrs.slug,
      searchTopics: true,
      setTopicContext: this.attrs.setTopicContext,
    });
    e.preventDefault();
    return false;
  }
}
