import { withPluginApi } from "discourse/lib/plugin-api";
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

export default {
  initialize(owner) {
    this.currentUser = owner.lookup("service:currentUser");

    if (!this.currentUser?.staff) {
      return;
    }

    withPluginApi("1.8.0", (api) => {
      api.addSidebarPanel(
        (BaseCustomSidebarPanel) =>
          class AdminSidebarPanel extends BaseCustomSidebarPanel {
            key = ADMIN_PANEL;
            hidden = true;
          }
      );

      let adminSectionLinkClass = null;

      // HACK: This is just an example, we need a better way of defining this data.
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
        {
          text: "Community",
          name: "community",
          links: [
            {
              name: "Item 1",
              route: "admin-revamp.config.area",
              routeModels: [{ area: "item-1" }],
              text: "Item 1",
            },
            {
              name: "Item 2",
              route: "admin-revamp.config.area",
              routeModels: [{ area: "item-2" }],
              text: "Item 2",
            },
          ],
        },
      ];

      adminNavSections.forEach((adminNavSectionData) => {
        api.addSidebarSection(
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
    });
  },
};
