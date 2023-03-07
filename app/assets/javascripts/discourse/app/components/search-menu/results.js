import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import { escapeExpression, formatUsername } from "discourse/lib/utilities";
import { deepMerge } from "discourse-common/lib/object";
import I18n from "I18n";
import RawHtml from "discourse/widgets/raw-html";
import { avatarImg } from "discourse/widgets/post";
import { createWidget } from "discourse/widgets/widget";
import { dateNode } from "discourse/helpers/node";
import { emojiUnescape } from "discourse/lib/text";
import getURL from "discourse-common/lib/get-url";
import { h } from "virtual-dom";
import highlightSearch from "discourse/lib/highlight-search";
import { iconNode } from "discourse-common/lib/icon-library";
import renderTag from "discourse/lib/render-tag";
import TopicViewComponent from "./results/type/topic";
import PostViewComponent from "./results/type/post";
import UserViewComponent from "./results/type/user";
import TagViewComponent from "./results/type/tag";
import GroupViewComponent from "./results/type/group";
import CategoryViewComponent from "./results/type/category";

const SEARCH_RESULTS_COMPONENT_TYPE = {
  category: CategoryViewComponent,
  topic: TopicViewComponent,
  post: PostViewComponent,
  user: UserViewComponent,
  tag: TagViewComponent,
  group: GroupViewComponent,
};

const DEFAULT_QUICK_TIPS = [
  {
    label: "#",
    description: I18n.t("search.tips.category_tag"),
    clickable: true,
  },
  {
    label: "@",
    description: I18n.t("search.tips.author"),
    clickable: true,
  },
  {
    label: "in:",
    description: I18n.t("search.tips.in"),
    clickable: true,
  },
  {
    label: "status:",
    description: I18n.t("search.tips.status"),
    clickable: true,
  },
  {
    label: I18n.t("search.tips.full_search_key", { modifier: "Ctrl" }),
    description: I18n.t("search.tips.full_search"),
  },
  {
    label: "@me",
    description: I18n.t("search.tips.me"),
  },
];

let QUICK_TIPS = [];

export function addQuickSearchRandomTip(tip) {
  if (!QUICK_TIPS.includes(tip)) {
    QUICK_TIPS.push(tip);
  }
}

export function resetQuickSearchRandomTips() {
  QUICK_TIPS = [].concat(DEFAULT_QUICK_TIPS);
}

resetQuickSearchRandomTips();

//function createSearchResult({ type, linkField, builder }) {
//return createWidget(`search-result-${type}`, {
//tagName: "ul.list",

//buildAttributes() {
//return {
//"aria-label": `${type} ${I18n.t("search.results")}`,
//};
//},

//html(attrs) {
//return attrs.results.map((r) => {
//let searchResultId;

//if (type === "topic") {
//searchResultId = r.topic_id;
//} else {
//searchResultId = r.id;
//}

//return h(
//"li.item",
//this.attach("link", {
//href: r[linkField],
//contents: () => builder.call(this, r, attrs.term),
//className: "search-link",
//searchResultId,
//searchResultType: type,
//searchLogId: attrs.searchLogId,
//})
//);
//});
//},
//});
//}

//function postResult(result, link, term) {
//const html = [link];

//if (!this.site.mobileView) {
//html.push(
//h("span.blurb", [
//dateNode(result.created_at),
//h("span", " - "),
//this.siteSettings.use_pg_headlines_for_excerpt
//? new RawHtml({ html: `<span>${result.blurb}</span>` })
//: new Highlighted(result.blurb, term),
//])
//);
//}

//return html;
//}

//createSearchResult({
//type: "tag",
//linkField: "url",
//builder(t) {
//const tag = escapeExpression(t.id);
//return [
//iconNode("tag"),
//new RawHtml({ html: renderTag(tag, { tagName: "span" }) }),
//];
//},
//});

//createSearchResult({
//type: "category",
//linkField: "url",
//builder(c) {
//return this.attach("category-link", { category: c, link: false });
//},
//});

//createSearchResult({
//type: "group",
//linkField: "url",
//builder(group) {
//const fullName = escapeExpression(group.fullName);
//const name = escapeExpression(group.name);
//const groupNames = [h("span.name", fullName || name)];

//if (fullName) {
//groupNames.push(h("span.slug", name));
//}

//let avatarFlair;
//if (group.flairUrl) {
//avatarFlair = this.attach("avatar-flair", {
//flair_name: name,
//flair_url: group.flairUrl,
//flair_bg_color: group.flairBgColor,
//flair_color: group.flairColor,
//});
//} else {
//avatarFlair = iconNode("users");
//}

//const groupResultContents = [avatarFlair, h("div.group-names", groupNames)];

//return h("div.group-result", groupResultContents);
//},
//});

//createSearchResult({
//type: "user",
//linkField: "path",
//builder(u) {
//const userTitles = [];

//if (u.name) {
//userTitles.push(h("span.name", u.name));
//}

//userTitles.push(h("span.username", formatUsername(u.username)));

//if (u.custom_data) {
//u.custom_data.forEach((row) =>
//userTitles.push(h("span.custom-field", `${row.name}: ${row.value}`))
//);
//}

//const userResultContents = [
//avatarImg("small", {
//template: u.avatar_template,
//username: u.username,
//}),
//h("div.user-titles", userTitles),
//];

//return h("div.user-result", userResultContents);
//},
//});

//createSearchResult({
//type: "topic",
//linkField: "url",
//builder(result, term) {
//const topic = result.topic;

//const firstLine = [
//this.attach("topic-status", { topic, disableActions: true }),
//h(
//"span.topic-title",
//{ attributes: { "data-topic-id": topic.id } },
//this.siteSettings.use_pg_headlines_for_excerpt &&
//result.topic_title_headline
//? new RawHtml({
//html: `<span>${emojiUnescape(
//result.topic_title_headline
//)}</span>`,
//})
//: new Highlighted(topic.fancyTitle, term)
//),
//];

//const secondLine = [
//this.attach("category-link", {
//category: topic.category,
//link: false,
//}),
//];
//if (this.siteSettings.tagging_enabled) {
//secondLine.push(
//this.attach("discourse-tags", { topic, tagName: "span" })
//);
//}

//const link = h("span.topic", [
//h("span.first-line", firstLine),
//h("span.second-line", secondLine),
//]);

//return postResult.call(this, result, link, term);
//},
//});

//createSearchResult({
//type: "post",
//linkField: "url",
//builder(result, term) {
//return postResult.call(
//this,
//result,
//I18n.t("search.post_format", result),
//term
//);
//},
//});

export default class Results extends Component {
  get results() {
    //const mainResultsContent = [];
    //const usersAndGroups = [];
    //const categoriesAndTags = [];

    //const buildMoreNode = (result) => {
    //const moreArgs = {
    //className: "filter search-link",
    //contents: () => [I18n.t("more"), "..."],
    //};

    //if (result.moreUrl) {
    //return this.attach(
    //"link",
    //deepMerge(moreArgs, {
    //href: result.moreUrl,
    //})
    //);
    //} else if (result.more) {
    //return this.attach(
    //"link",
    //deepMerge(moreArgs, {
    //action: "moreOfType",
    //actionParam: result.type,
    //})
    //);
    //}
    //};

    //const assignContainer = (result, node) => {
    //if (searchTopics) {
    //if (["topic"].includes(result.type)) {
    //mainResultsContent.push(node);
    //}
    //} else {
    //if (["user", "group"].includes(result.type)) {
    //usersAndGroups.push(node);
    //}

    //if (["category", "tag"].includes(result.type)) {
    //categoriesAndTags.push(node);
    //}
    //}
    //};

    //resultTypes.forEach((rt) => {
    //const resultNodeContents = [
    //this.attach(rt.componentName, {
    //searchLogId: attrs.results.grouped_search_result.search_log_id,
    //results: rt.results,
    //term,
    //}),
    //];

    //if (["topic"].includes(rt.type)) {
    //const more = buildMoreNode(rt);
    //if (more) {
    //resultNodeContents.push(h("div.search-menu__show-more", more));
    //}
    //}

    //assignContainer(rt, h(`div.${rt.componentName}`, resultNodeContents));
    //});

    const content = [];

    return this.results.resultTypes?.map((result) => {
      debugger;
      content.push(SEARCH_RESULTS_COMPONENT_TYPE[result.type]);
    });

    //if (!searchTopics) {
    //if (!attrs.inPMInboxContext) {
    //content.push(this.attach("search-menu-initial-options", { term }));
    //}
    //} else {
    //if (mainResultsContent.length) {
    //content.push(mainResultsContent);
    //} else {
    //return h("div.no-results", I18n.t("search.no_results"));
    //}
    //}

    //content.push(categoriesAndTags);
    //content.push(usersAndGroups);

    //return content;
  }

  moreOfType(type) {
    searchData.typeFilter = type;
    this.triggerSearch();
  }
}

class Highlighted extends RawHtml {
  constructor(html, term) {
    super({ html: `<span>${html}</span>` });
    this.term = term;
  }

  decorate($html) {
    highlightSearch($html[0], this.term);
  }
}
