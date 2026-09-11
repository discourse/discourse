import typography from "../components/sections/atoms/00-typography.gjs";
import fontScale from "../components/sections/atoms/01-font-scale.gjs";
import buttons from "../components/sections/atoms/02-buttons.gjs";
import colors from "../components/sections/atoms/03-colors.gjs";
import icons from "../components/sections/atoms/04-icons.gjs";
import forms from "../components/sections/atoms/05-forms.gjs";
import spinners from "../components/sections/atoms/06-spinners.gjs";
import otp from "../components/sections/atoms/07-otp.gjs";
import dateTimeInputs from "../components/sections/atoms/08-date-time-inputs.gjs";
import dropdowns from "../components/sections/atoms/09-dropdowns.gjs";
import topicLink from "../components/sections/atoms/10-topic-link-status.gjs";
import shortcut from "../components/sections/atoms/11-shortcut.gjs";
import breadCrumbs from "../components/sections/molecules/bread-crumbs.gjs";
import categories from "../components/sections/molecules/categories.gjs";
import charCounter from "../components/sections/molecules/char-counter.gjs";
import comboButton from "../components/sections/molecules/combo-button.gjs";
import contextMenu from "../components/sections/molecules/context-menu.gjs";
import dialog from "../components/sections/molecules/dialog.gjs";
import dragAndDrop from "../components/sections/molecules/drag-and-drop.gjs";
import emptyState from "../components/sections/molecules/empty-state.gjs";
import menus from "../components/sections/molecules/menus.gjs";
import multiselect from "../components/sections/molecules/multi-select.gjs";
import navigationBar from "../components/sections/molecules/navigation-bar.gjs";
import navigationStacked from "../components/sections/molecules/navigation-stacked.gjs";
import overflowControls from "../components/sections/molecules/overflow-controls.gjs";
import postMenu from "../components/sections/molecules/post-menu.gjs";
import rovingFocus from "../components/sections/molecules/roving-focus.gjs";
import segmentedControl from "../components/sections/molecules/segmented-control.gjs";
import signupCta from "../components/sections/molecules/signup-cta.gjs";
import tabs from "../components/sections/molecules/tabs.gjs";
import toasts from "../components/sections/molecules/toasts.gjs";
import tooltips from "../components/sections/molecules/tooltips.gjs";
import topicListItem from "../components/sections/molecules/topic-list-item.gjs";
import topicNotifications from "../components/sections/molecules/topic-notifications.gjs";
import topicTimerInfo from "../components/sections/molecules/topic-timer-info.gjs";
import virtualList from "../components/sections/molecules/virtual-list.gjs";
import post from "../components/sections/organisms/00-post.gjs";
import postList from "../components/sections/organisms/01-post-list.gjs";
import postOneboxes from "../components/sections/organisms/02-post-oneboxes.gjs";
import topicMap from "../components/sections/organisms/03-topic-map.gjs";
import topicFooterButtons from "../components/sections/organisms/04-topic-footer-buttons.gjs";
import topicList from "../components/sections/organisms/05-topic-list.gjs";
import basicTopicList from "../components/sections/organisms/basic-topic-list.gjs";
import categoriesList from "../components/sections/organisms/categories-list.gjs";
import dockedComposer from "../components/sections/organisms/docked-composer.gjs";
import modal from "../components/sections/organisms/modal.gjs";
import moreTopics from "../components/sections/organisms/more-topics.gjs";
import navigation from "../components/sections/organisms/navigation.gjs";
import siteHeader from "../components/sections/organisms/site-header.gjs";
import bem from "../components/sections/syntax/00-bem.gjs";

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
  { component: otp, category: "atoms", id: "otp", priority: 7 },
  { component: dateTimeInputs, category: "atoms", id: "date-time-inputs" },
  { component: dropdowns, category: "atoms", id: "dropdowns" },
  { component: topicLink, category: "atoms", id: "topic-link" },
  { component: shortcut, category: "atoms", id: "shortcut" },
  {
    component: segmentedControl,
    category: "atoms",
    id: "segmented-control",
  },
  { component: breadCrumbs, category: "molecules", id: "bread-crumbs" },
  { component: categories, category: "molecules", id: "categories" },
  { component: charCounter, category: "molecules", id: "char-counter" },
  { component: comboButton, category: "molecules", id: "combo-button" },
  { component: emptyState, category: "molecules", id: "empty-state" },
  { component: navigationBar, category: "molecules", id: "navigation-bar" },
  {
    component: navigationStacked,
    category: "molecules",
    id: "navigation-stacked",
  },
  { component: postMenu, category: "molecules", id: "post-menu" },
  { component: rovingFocus, category: "molecules", id: "roving-focus" },
  { component: tooltips, category: "molecules", id: "tooltips" },
  { component: menus, category: "molecules", id: "menus" },
  { component: contextMenu, category: "molecules", id: "context-menu" },
  { component: multiselect, category: "molecules", id: "multi-select" },
  { component: toasts, category: "molecules", id: "toasts" },
  { component: dialog, category: "molecules", id: "dialog" },
  { component: dragAndDrop, category: "molecules", id: "drag-and-drop" },
  { component: signupCta, category: "molecules", id: "signup-cta" },
  { component: topicListItem, category: "molecules", id: "topic-list-item" },
  {
    component: topicNotifications,
    category: "molecules",
    id: "topic-notifications",
  },
  { component: topicTimerInfo, category: "molecules", id: "topic-timer-info" },
  { component: virtualList, category: "molecules", id: "virtual-list" },
  { component: tabs, category: "molecules", id: "tabs" },
  {
    component: overflowControls,
    category: "molecules",
    id: "overflow-controls",
  },
  { component: post, category: "organisms", id: "post", priority: 0 },
  { component: postList, category: "organisms", id: "post-list", priority: 1 },
  {
    component: postOneboxes,
    category: "organisms",
    id: "post-oneboxes",
    priority: 2,
  },
  { component: topicMap, category: "organisms", id: "topic-map", priority: 3 },
  {
    component: topicFooterButtons,
    category: "organisms",
    id: "topic-footer-buttons",
    priority: 4,
  },
  {
    component: topicList,
    category: "organisms",
    id: "topic-list",
    priority: 5,
  },
  { component: basicTopicList, category: "organisms", id: "basic-topic-list" },
  { component: categoriesList, category: "organisms", id: "categories-list" },
  { component: dockedComposer, category: "organisms", id: "docked-composer" },
  { component: modal, category: "organisms", id: "modal" },
  { component: navigation, category: "organisms", id: "navigation" },
  { component: siteHeader, category: "organisms", id: "site-header" },
  { component: moreTopics, category: "organisms", id: "more-topics" },
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
