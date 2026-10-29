import { getOwnerWithFallback } from "discourse/lib/get-owner";
import BaseCustomSidebarPanel from "discourse/lib/sidebar/base-custom-sidebar-panel";
import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import BaseCustomSidebarSectionLink from "discourse/lib/sidebar/base-custom-sidebar-section-link";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
import { i18n } from "discourse-i18n";
import AdminSidebarPanel from "./admin-sidebar.js";
import UserNavSidebarPanel from "./user-nav-sidebar.js";

class MainSidebarPanel extends BaseCustomSidebarPanel {
  scrollActiveLinkIntoView = true;
  expandActiveSection = false;

  get key() {
    return "main";
  }

  get switchButtonLabel() {
    return i18n("sidebar.panels.forum.label");
  }

  get switchButtonIcon() {
    return "shuffle";
  }

  get switchButtonDefaultUrl() {
    return this?.lastKnownURL || "/";
  }

  get mobileTab() {
    const owner = getOwnerWithFallback(this);
    const currentUser = owner.lookup("service:current-user");
    const composer = () => owner.lookup("service:composer");

    return {
      label: i18n("mobile_tab_bar.topics"),
      icon: "layer-group",
      url: "/",
      isNestedRoute: (routeInfo) => routeInfo.name.startsWith("topic."),
      showsTitleInHeader: () => true,
      createActions: [
        currentUser?.can_create_topic && {
          label: i18n("mobile_tab_bar.new_topic"),
          icon: "far-pen-to-square",
          action: () => {
            // A category or topic page, or a tag's list, seeds the new topic
            const attributes =
              owner.lookup("service:router").currentRoute?.attributes;

            composer().openNewTopic({
              category: attributes?.category,
              tags: attributes?.tag?.name,
            });
          },
        },
        currentUser?.can_send_private_messages && {
          label: i18n("mobile_tab_bar.new_personal_message"),
          icon: "envelope",
          action: () => composer().openNewMessage({}),
        },
      ].filter(Boolean),
    };
  }
}

export let customPanels;
export let currentPanelKey;
resetSidebarPanels();

export function addSidebarPanel(func) {
  const panelClass = func.call(this, BaseCustomSidebarPanel);
  customPanels.push(new panelClass());
}

export function addSidebarSection(func, panelKey) {
  const panel = customPanels.find((p) => p.key === panelKey);
  if (!panel) {
    // eslint-disable-next-line no-console
    return console.warn(
      `Error adding section to ${panelKey} because panel doesn't exist. Check addSidebarPanel API.`
    );
  }
  // Reassigned so pages showing the panel pick up sections added later
  panel.sections = [
    ...panel.sections,
    func.call(this, BaseCustomSidebarSection, BaseCustomSidebarSectionLink),
  ];
}

export function resetPanelSections(
  panelKey,
  newSections = null,
  sectionBuilder = null
) {
  const panel = customPanels.find((item) => item.key === panelKey);
  if (newSections) {
    panel.sections = [];
    sectionBuilder(newSections);
  } else {
    panel.sections = [];
  }
}

export function resetSidebarPanels() {
  customPanels = [
    new MainSidebarPanel(),
    new AdminSidebarPanel(),
    new UserNavSidebarPanel(),
  ];
  currentPanelKey = MAIN_PANEL;
}
