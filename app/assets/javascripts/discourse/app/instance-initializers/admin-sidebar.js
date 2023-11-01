import { ADMIN_NAV_MAP } from "discourse/lib/sidebar/admin-nav-map";
import {
  addSidebarPanel,
  addSidebarSection,
} from "discourse/lib/sidebar/custom-sections";
import { ADMIN_PANEL } from "discourse/services/sidebar-state";

function defineAdminSectionLink(BaseCustomSidebarSectionLink) {
  const SidebarAdminSectionLink = class extends BaseCustomSidebarSectionLink {
    constructor({ adminSidebarNavLink }) {
      super(...arguments);
      this.adminSidebarNavLink = adminSidebarNavLink;
    }

    get name() {
      return this.adminSidebarNavLink.name;
    }

    get classNames() {
      return "admin-sidebar-nav-link";
    }

    get route() {
      return this.adminSidebarNavLink.route;
    }

    get href() {
      return this.adminSidebarNavLink.href;
    }

    get models() {
      return this.adminSidebarNavLink.routeModels;
    }

    get text() {
      return this.adminSidebarNavLink.text;
    }

    get prefixType() {
      return "icon";
    }

    get prefixValue() {
      return this.adminSidebarNavLink.icon;
    }

    get title() {
      return this.adminSidebarNavLink.text;
    }
  };

  return SidebarAdminSectionLink;
}

function defineAdminSection(
  adminNavSectionData,
  BaseCustomSidebarSection,
  adminSectionLinkClass
) {
  const AdminNavSection = class extends BaseCustomSidebarSection {
    constructor() {
      super(...arguments);
      this.adminNavSectionData = adminNavSectionData;
      this.hideSectionHeader = adminNavSectionData.hideSectionHeader;
    }

    get sectionLinks() {
      return this.adminNavSectionData.links;
    }

    get name() {
      return `admin-nav-section-${this.adminNavSectionData.name}`;
    }

    get title() {
      return this.adminNavSectionData.text;
    }

    get text() {
      return this.adminNavSectionData.text;
    }

    get links() {
      return this.sectionLinks.map(
        (sectionLinkData) =>
          new adminSectionLinkClass({ adminSidebarNavLink: sectionLinkData })
      );
    }

    get displaySection() {
      return true;
    }
  };

  return AdminNavSection;
}

export function useAdminNavConfig(navMap) {
  const adminNavSections = [
    {
      text: "",
      name: "root",
      hideSectionHeader: true,
      links: [
        {
          name: "Back to Forum",
          route: "discovery.latest",
          text: "Back to Forum",
          icon: "arrow-left",
        },
        {
          name: "Lobby",
          route: "admin-revamp.lobby",
          text: "Lobby",
          icon: "home",
        },
        {
          name: "legacy",
          route: "admin",
          text: "Legacy Admin",
          icon: "wrench",
        },
      ],
    },
  ];

  return adminNavSections.concat(navMap);
}

let adminSectionLinkClass = null;
export function buildAdminSidebar(navConfig) {
  navConfig.forEach((adminNavSectionData) => {
    addSidebarSection(
      (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
        // We only want to define the link class once even though we have many different sections.
        adminSectionLinkClass =
          adminSectionLinkClass ||
          defineAdminSectionLink(BaseCustomSidebarSectionLink);

        return defineAdminSection(
          adminNavSectionData,
          BaseCustomSidebarSection,
          adminSectionLinkClass
        );
      },
      ADMIN_PANEL
    );
  });
}

export default {
  initialize(owner) {
    this.currentUser = owner.lookup("service:currentUser");
    this.siteSettings = owner.lookup("service:site-settings");

    if (!this.currentUser?.staff) {
      return;
    }

    if (
      !this.siteSettings.userInAnyGroups(
        "enable_experimental_admin_ui_groups",
        this.currentUser
      )
    ) {
      return;
    }

    this.adminSidebarExperimentStateManager = owner.lookup(
      "service:admin-sidebar-experiment-state-manager"
    );

    addSidebarPanel(
      (BaseCustomSidebarPanel) =>
        class AdminSidebarPanel extends BaseCustomSidebarPanel {
          key = ADMIN_PANEL;
          hidden = true;
        }
    );

    const savedConfig = this.adminSidebarExperimentStateManager.navConfig;
    const navConfig = useAdminNavConfig(savedConfig || ADMIN_NAV_MAP);
    buildAdminSidebar(navConfig, adminSectionLinkClass);
  },
};
