import typography from "../components/sections/atoms/00-typography";
import fontScale from "../components/sections/atoms/01-font-scale";
import buttons from "../components/sections/atoms/02-buttons";
import colors from "../components/sections/atoms/03-colors";
import icons from "../components/sections/atoms/04-icons";
import forms from "../components/sections/atoms/05-forms";
import spinners from "../components/sections/atoms/06-spinners";
import dateTimeInputs from "../components/sections/atoms/date-time-inputs";
import dropdowns from "../components/sections/atoms/dropdowns";
import topicLink from "../components/sections/atoms/topic-link";
import topicStatuses from "../components/sections/atoms/topic-statuses";
import breadCrumbs from "../components/sections/molecules/bread-crumbs";
import categories from "../components/sections/molecules/categories";
import charCounter from "../components/sections/molecules/char-counter";
import emptyState from "../components/sections/molecules/empty-state";
import footerMessage from "../components/sections/molecules/footer-message";
import menus from "../components/sections/molecules/menus";
import navigationBar from "../components/sections/molecules/navigation-bar";
import navigationStacked from "../components/sections/molecules/navigation-stacked";
import postMenu from "../components/sections/molecules/post-menu";
import signupCta from "../components/sections/molecules/signup-cta";
import toasts from "../components/sections/molecules/toasts";
import tooltips from "../components/sections/molecules/tooltips";
import topicListItem from "../components/sections/molecules/topic-list-item";
import topicNotifications from "../components/sections/molecules/topic-notifications";
import topicTimerInfo from "../components/sections/molecules/topic-timer-info";
import post from "../components/sections/organisms/00-post";
import postList from "../components/sections/organisms/01-post-list";
import topicMap from "../components/sections/organisms/02-topic-map";
import topicFooterButtons from "../components/sections/organisms/03-topic-footer-buttons";
import topicList from "../components/sections/organisms/04-topic-list";
import basicTopicList from "../components/sections/organisms/basic-topic-list";
import categoriesList from "../components/sections/organisms/categories-list";
import modal from "../components/sections/organisms/modal";
import navigation from "../components/sections/organisms/navigation";
import siteHeader from "../components/sections/organisms/site-header";
import suggestedTopics from "../components/sections/organisms/suggested-topics";
import userAbout from "../components/sections/organisms/user-about";
import bem from "../components/sections/syntax/00-bem";

let _allCategories = null;
let _sectionsById = {};

export const CATEGORIES = ["syntax", "atoms", "molecules", "organisms"];

const SECTIONS = [
  { component: bem, category: "syntax", id: "bem", priority: 0 },
  { component: typography, category: "atoms", id: "typography", priority: 0 },
  { component: fontScale, category: "atoms", id: "font-scale", priority: 1 },
  { component: buttons, category: "atoms", id: "buttons", priority: 2 },
  { component: colors, category: "atoms", id: "colors", priority: 3 },
  { component: icons, category: "atoms", id: "icons", priority: 4 },
  {
    component: forms,
    category: "atoms",
    id: "forms",
    priority: 5,
  },
  { component: spinners, category: "atoms", id: "spinners", priority: 6 },
  { component: dateTimeInputs, category: "atoms", id: "date-time-inputs" },
  { component: dropdowns, category: "atoms", id: "dropdowns" },
  { component: topicLink, category: "atoms", id: "topic-link" },
  { component: topicStatuses, category: "atoms", id: "topic-statuses" },
  { component: breadCrumbs, category: "molecules", id: "bread-crumbs" },
  { component: categories, category: "molecules", id: "categories" },
  { component: charCounter, category: "molecules", id: "char-counter" },
  { component: emptyState, category: "molecules", id: "empty-state" },
  { component: footerMessage, category: "molecules", id: "footer-message" },
  { component: navigationBar, category: "molecules", id: "navigation-bar" },
  {
    component: navigationStacked,
    category: "molecules",
    id: "navigation-stacked",
  },
  { component: postMenu, category: "molecules", id: "post-menu" },
  { component: tooltips, category: "molecules", id: "tooltips" },
  { component: menus, category: "molecules", id: "menus" },
  { component: toasts, category: "molecules", id: "toasts" },
  { component: signupCta, category: "molecules", id: "signup-cta" },
  { component: topicListItem, category: "molecules", id: "topic-list-item" },
  {
    component: topicNotifications,
    category: "molecules",
    id: "topic-notifications",
  },
  { component: topicTimerInfo, category: "molecules", id: "topic-timer-info" },
  { component: post, category: "organisms", id: "post", priority: 0 },
  { component: postList, category: "organisms", id: "post-list", priority: 1 },
  { component: topicMap, category: "organisms", id: "topic-map", priority: 2 },
  {
    component: topicFooterButtons,
    category: "organisms",
    id: "topic-footer-buttons",
    priority: 3,
  },
  {
    component: topicList,
    category: "organisms",
    id: "topic-list",
    priority: 4,
  },
  { component: basicTopicList, category: "organisms", id: "basic-topic-list" },
  { component: categoriesList, category: "organisms", id: "categories-list" },
  { component: modal, category: "organisms", id: "modal" },
  { component: navigation, category: "organisms", id: "navigation" },
  { component: siteHeader, category: "organisms", id: "site-header" },
  { component: suggestedTopics, category: "organisms", id: "suggested-topics" },
  { component: userAbout, category: "organisms", id: "user-about" },
];

export function addSection(section) {
  if (!SECTIONS.some((s) => s.id === section.id)) {
    SECTIONS.push(section);
  }
}

export function sectionById(id) {
  // prime cache
  allCategories();

  return _sectionsById[id];
}

function sortSections(a, b) {
  const result = a.priority - b.priority;

  if (result !== 0) {
    return result;
  }

  return a.id < b.id ? -1 : 1;
}

export function allCategories() {
  if (_allCategories) {
    return _allCategories;
  }

  for (const section of SECTIONS) {
    section.priority ??= 100;

    categories[section.category] ||= [];
    categories[section.category].push(section);

    _sectionsById[section.id] = section;
  }

  _allCategories = [];
  for (const category of CATEGORIES) {
    const sections = categories[category];

    if (sections) {
      _allCategories.push({
        id: category,
        sections: sections.sort(sortSections),
      });
    }
  }

  return _allCategories;
}
