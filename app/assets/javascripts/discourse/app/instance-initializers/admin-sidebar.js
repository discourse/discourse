import PreloadStore from "discourse/lib/preload-store";
import { ADMIN_NAV_MAP } from "discourse/lib/sidebar/admin-nav-map";
import {
  addSidebarPanel,
  addSidebarSection,
} from "discourse/lib/sidebar/custom-sections";
import { ADMIN_PANEL } from "discourse/services/sidebar-state";
import I18n from "discourse-i18n";

const additionalAdminSidebarSectionLinks = {};

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
      return this.adminSidebarNavLink.label
        ? I18n.t(this.adminSidebarNavLink.label)
        : this.adminSidebarNavLink.text;
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
      return this.adminNavSectionData.label
        ? I18n.t(this.adminNavSectionData.label)
        : this.adminNavSectionData.text;
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
          name: "back_to_forum",
          route: "discovery.latest",
          label: "admin.back_to_forum",
          icon: "arrow-left",
        },
        {
          name: "admin_dashboard",
          route: "admin.dashboard",
          label: "admin.dashboard.title",
          icon: "home",
        },
        {
          name: "admin_site_settings",
          route: "adminSiteSettings",
          label: "admin.site_settings.title",
          icon: "cog",
        },
        {
          name: "admin_users",
          route: "adminUsers",
          label: "admin.users.title",
          icon: "users",
        },
        {
          name: "admin_badges",
          route: "adminBadges",
          label: "admin.badges.title",
          icon: "certificate",
        },
      ],
    },
  ];

  navMap = adminNavSections.concat(navMap);

  for (const [sectionName, additionalLinks] of Object.entries(
    additionalAdminSidebarSectionLinks
  )) {
    const section = navMap.findBy("name", sectionName);
    if (section && additionalLinks.length) {
      section.links.push(...additionalLinks);
    }
  }

  return navMap;
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

export function addAdminSidebarSectionLink(sectionName, link) {
  if (!additionalAdminSidebarSectionLinks.hasOwnProperty(sectionName)) {
    additionalAdminSidebarSectionLinks[sectionName] = [];
  }

  // make the name extra-unique
  link.name = `admin_additional_${sectionName}_${link.name}`;

  // href or route needs to be provided
  if (!link.href && !link.route) {
    return;
  }

  // label must be valid, don't want broken [XYZ translation missing]
  if (!I18n.lookup(link.label)) {
    return;
  }

  additionalAdminSidebarSectionLinks[sectionName].push(link);
}

function pluginAdminRouteLinks() {
  return (PreloadStore.get("enabledPluginAdminRoutes") || []).map(
    (pluginAdminRoute) => {
      return {
        name: `admin_plugin_${pluginAdminRoute.location}`,
        route: `adminPlugins.${pluginAdminRoute.location}`,
        label: pluginAdminRoute.label,
        icon: "cog",
      };
    }
  );
}

export default {
  name: "admin-sidebar-initializer",

  initialize(owner) {
    this.currentUser = owner.lookup("service:current-user");
    this.siteSettings = owner.lookup("service:site-settings");

    if (
      !this.currentUser?.staff ||
      !this.siteSettings.userInAnyGroups(
        "admin_sidebar_enabled_groups",
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
    const navMap = savedConfig || ADMIN_NAV_MAP;

    navMap
      .findBy("name", "admin_plugins")
      .links.push(...pluginAdminRouteLinks());

    if (this.siteSettings.experimental_form_templates) {
      navMap.findBy("name", "customize").links.push({
        name: "admin_customize_form_templates",
        route: "adminCustomizeFormTemplates",
        label: "admin.form_templates.nav_title",
        icon: "list",
      });
    }

    buildAdminSidebar(useAdminNavConfig(navMap), adminSectionLinkClass);
  },
};
