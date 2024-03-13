import { cached } from "@glimmer/tracking";
import PreloadStore from "discourse/lib/preload-store";
import { ADMIN_NAV_MAP } from "discourse/lib/sidebar/admin-nav-map";
import BaseCustomSidebarPanel from "discourse/lib/sidebar/base-custom-sidebar-panel";
import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import BaseCustomSidebarSectionLink from "discourse/lib/sidebar/base-custom-sidebar-section-link";
import { ADMIN_PANEL } from "discourse/lib/sidebar/panels";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import I18n from "discourse-i18n";

let additionalAdminSidebarSectionLinks = {};

// For testing.
export function clearAdditionalAdminSidebarSectionLinks() {
  additionalAdminSidebarSectionLinks = {};
}

class SidebarAdminSectionLink extends BaseCustomSidebarSectionLink {
  constructor({
    adminSidebarNavLink,
    adminSidebarExperimentStateManager,
    router,
  }) {
    super(...arguments);
    this.router = router;
    this.adminSidebarNavLink = adminSidebarNavLink;
    this.adminSidebarStateManager = adminSidebarStateManager;
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

  get query() {
    return this.adminSidebarNavLink.query;
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

  get currentWhen() {
    // This is needed because the setting route is underneath /admin/plugins/:plugin_id,
    // but is not a child route of the plugin routes themselves. E.g. discourse-ai
    // for the plugin ID has its own nested routes defined in the plugin.
    if (this.router.currentRoute.name === "adminPlugins.show.settings") {
      if (
        this.adminSidebarNavLink.route?.includes(
          this.router.currentRoute.parent.params.plugin_id
        )
      ) {
        return this.router.currentRoute.name;
      }
    }

    return this.adminSidebarNavLink.route;
  }
  get keywords() {
    return (
      this.adminSidebarNavLink.keywords ||
      this.adminSidebarStateManager.keywords[this.adminSidebarNavLink.name] ||
      []
    );
  }
}

function defineAdminSection(
  adminNavSectionData,
  adminSidebarExperimentStateManager,
  router
) {
  const AdminNavSection = class extends BaseCustomSidebarSection {
    constructor() {
      super(...arguments);
      this.adminNavSectionData = adminNavSectionData;
      this.hideSectionHeader = adminNavSectionData.hideSectionHeader;
      this.adminSidebarStateManager = adminSidebarStateManager;
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
          new SidebarAdminSectionLink({
            adminSidebarNavLink: sectionLinkData,
            adminSidebarExperimentStateManager:
              this.adminSidebarExperimentStateManager,
            router,
          })
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
          name: "admin_home",
          route: "admin.dashboard.general",
          label: "admin.dashboard.title",
          icon: "home",
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

// This is used for a plugin API.
export function addAdminSidebarSectionLink(sectionName, link) {
  if (!additionalAdminSidebarSectionLinks.hasOwnProperty(sectionName)) {
    additionalAdminSidebarSectionLinks[sectionName] = [];
  }

  // make the name extra-unique
  link.name = `admin_additional_${sectionName}_${link.name}`;

  if (!link.href && !link.route) {
    // eslint-disable-next-line no-console
    console.debug(
      "[AdminSidebar]",
      `Custom link ${sectionName}_${link.name} must have either href or route`
    );
    return;
  }

  if (!link.label && !link.text) {
    // eslint-disable-next-line no-console
    console.debug(
      "[AdminSidebar]",
      `Custom link ${sectionName}_${link.name} must have either label (which is an I18n key) or text`
    );
    return;
  }

  // label must be valid, don't want broken [XYZ translation missing]
  if (link.label && typeof I18n.lookup(link.label) !== "string") {
    // eslint-disable-next-line no-console
    console.debug(
      "[AdminSidebar]",
      `Custom link ${sectionName}_${link.name} must have a valid I18n label, got ${link.label}`
    );
    return;
  }

  additionalAdminSidebarSectionLinks[sectionName].push(link);
}

function pluginAdminRouteLinks() {
  return (PreloadStore.get("visiblePlugins") || [])
    .filter((plugin) => plugin.admin_route && plugin.enabled)
    .map((plugin) => {
      return {
        name: `admin_plugin_${plugin.admin_route.location}`,
        route: plugin.admin_route.use_new_show_route
          ? `adminPlugins.show.${plugin.admin_route.location}`
          : `adminPlugins.${plugin.admin_route.location}`,
        routeModels: plugin.admin_route.use_new_show_route
          ? [plugin.admin_route.location]
          : [],
        label: pluginAdminRoute.label,
        icon: "cog",
      };
    });
}

export default class AdminSidebarPanel extends BaseCustomSidebarPanel {
  key = ADMIN_PANEL;
  hidden = true;

  @cached
  get sections() {
    const currentUser = getOwnerWithFallback(this).lookup(
      "service:current-user"
    );
    const siteSettings = getOwnerWithFallback(this).lookup(
      "service:site-settings"
    );
    const router = getOwnerWithFallback(this).lookup("service:router");
    const session = getOwnerWithFallback(this).lookup("service:session");
    if (!currentUser.use_admin_sidebar) {
      return [];
    }

    this.adminSidebarStateManager = getOwnerWithFallback(this).lookup(
      "service:admin-sidebar-state-manager"
    );

    const savedConfig = this.adminSidebarStateManager.navConfig;
    const navMap = savedConfig || ADMIN_NAV_MAP;

    if (!session.get("safe_mode")) {
      navMap.findBy("name", "plugins").links.push(...pluginAdminRouteLinks());
    }

    if (siteSettings.experimental_form_templates) {
      navMap.findBy("name", "appearance").links.push({
        name: "admin_customize_form_templates",
        route: "adminCustomizeFormTemplates",
        label: "admin.form_templates.nav_title",
        icon: "list",
      });
    }

    const navConfig = useAdminNavConfig(navMap);

    return navConfig.map((adminNavSectionData) => {
      return defineAdminSection(
        adminNavSectionData,
        this.adminSidebarStateManager,
        router
      );
    });
  }

  get filterable() {
    return true;
  }
}
