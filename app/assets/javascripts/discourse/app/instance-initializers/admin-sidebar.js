// Add more imports here if you want to add different nav layouts.
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

function useNavConfig(navMap) {
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

export default {
  initialize(owner) {
    this.currentUser = owner.lookup("service:currentUser");

    if (!this.currentUser?.staff) {
      return;
    }

    addSidebarPanel(
      (BaseCustomSidebarPanel) =>
        class AdminSidebarPanel extends BaseCustomSidebarPanel {
          key = ADMIN_PANEL;
          hidden = true;
        }
    );

    let adminSectionLinkClass = null;

    // NOTE: To make your own structure, simply copy different sections and links
    // from the ADMIN_NAV_MAP inside of discourse/lib/sidebar/admin-nav-map.js
    // into a new file under discourse/lib/sidebar/ , then import it above. Then,
    // add a line `const yourConfigName = useNavConfig(yourNavMap);`, then change
    // `defaultConfig.forEach` to `yourConfig.forEach`.
    //
    // You can also add unlimited new admin "config area" links, which are in this
    // format, and are meant to be used to render custom UIs for experimentation.
    // You just need to alter admin-revamp-config-area.hbs to render the component
    // you need based on the `@model.area` argument.
    //
    // {
    //   name: "Item 1",
    //   route: "admin-revamp.config.area",
    //   routeModels: [{ area: "item-1" }],
    //   text: "Item 1",
    // },

    const defaultConfig = useNavConfig(ADMIN_NAV_MAP);
    defaultConfig.forEach((adminNavSectionData) => {
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
  },
};
