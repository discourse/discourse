import { cached } from "@glimmer/tracking";
import { warn } from "@ember/debug";
import { configNavForPlugin } from "discourse/lib/admin-plugin-config-nav";
import { adminRouteValid } from "discourse/lib/admin-utilities";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import getURL from "discourse/lib/get-url";
import PreloadStore from "discourse/lib/preload-store";
import BaseCustomSidebarPanel from "discourse/lib/sidebar/base-custom-sidebar-panel";
import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import BaseCustomSidebarSectionLink from "discourse/lib/sidebar/base-custom-sidebar-section-link";
import { ADMIN_PANEL } from "discourse/lib/sidebar/panels";
import { escapeExpression } from "discourse/lib/utilities";
import I18n, { i18n } from "discourse-i18n";

let additionalAdminSidebarSectionLinks = {};

// For testing.
export function clearAdditionalAdminSidebarSectionLinks() {
  additionalAdminSidebarSectionLinks = {};
}

class SidebarAdminSectionLink extends BaseCustomSidebarSectionLink {
  constructor({
    adminSidebarNavLink,
    adminSidebarStateManager,
    router,
    currentUser,
  }) {
    super(...arguments);
    this.router = router;
    this.currentUser = currentUser;
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
    if (this.adminSidebarNavLink.href) {
      return getURL(this.adminSidebarNavLink.href);
    }
  }

  get query() {
    return this.adminSidebarNavLink.query;
  }

  get models() {
    return this.adminSidebarNavLink.routeModels;
  }

  get text() {
    return this.adminSidebarNavLink.label
      ? i18n(this.adminSidebarNavLink.label, {
          translatedFallback: this.adminSidebarNavLink.text,
        })
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
        this.adminSidebarNavLink.route?.split(".").last ===
        this.router.currentRoute.parent.params.plugin_id
      ) {
        return this.router.currentRoute.name;
      }
    }
    if (this.adminSidebarNavLink.currentWhen) {
      return this.adminSidebarNavLink.currentWhen;
    }
  }

  get keywords() {
    return (
      this.adminSidebarStateManager.keywords[this.adminSidebarNavLink.name] || {
        navigation: [],
      }
    );
  }

  get suffixType() {
    if (this.#hasUnseenFeatures) {
      return "icon";
    }
  }

  get suffixValue() {
    if (this.#hasUnseenFeatures) {
      return "circle";
    }
  }

  get suffixCSSClass() {
    if (this.#hasUnseenFeatures) {
      return "admin-sidebar-nav-link__dot";
    }
  }

  get #hasUnseenFeatures() {
    return (
      this.adminSidebarNavLink.name === "admin_whats_new" &&
      this.currentUser.hasUnseenFeatures
    );
  }
}

function defineAdminSection(
  adminNavSectionData,
  adminSidebarStateManager,
  router,
  currentUser
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
      return `${ADMIN_PANEL}-${this.adminNavSectionData.name}`;
    }

    get title() {
      return this.adminNavSectionData.text;
    }

    get text() {
      return this.adminNavSectionData.label
        ? i18n(this.adminNavSectionData.label)
        : this.adminNavSectionData.text;
    }

    get links() {
      return this.sectionLinks.map(
        (sectionLinkData) =>
          new SidebarAdminSectionLink({
            adminSidebarNavLink: sectionLinkData,
            adminSidebarStateManager: this.adminSidebarStateManager,
            router,
            currentUser,
          })
      );
    }

    get displaySection() {
      return true;
    }

    get collapsedByDefault() {
      return this.adminNavSectionData.name !== "root";
    }
  };

  return AdminNavSection;
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
  if (
    link.label &&
    i18n(link.label) === I18n.missingTranslation(link.label, null, {})
  ) {
    // eslint-disable-next-line no-console
    console.debug(
      "[AdminSidebar]",
      `Custom link ${sectionName}_${link.name} must have a valid I18n label, got ${link.label}`
    );
    return;
  }

  additionalAdminSidebarSectionLinks[sectionName].push(link);
}

function pluginAdminRouteLinks(router) {
  return (PreloadStore.get("visiblePlugins") || [])
    .filter((plugin) => {
      if (!plugin.admin_route || !plugin.enabled) {
        return false;
      }

      // Check if the admin route is valid, if it is not the whole admin
      // interface can break because of this. This can be the case for things
      // like ad blockers stopping plugin JS from loading.
      if (adminRouteValid(router, plugin.admin_route)) {
        return true;
      } else {
        warn(
          `[AdminSidebar] Could not find admin route for ${plugin.name}, route was ${plugin.admin_route.full_location}. This could be caused by an ad blocker.`,
          { id: "discourse.admin-sidebar:plugin-admin-route-links" }
        );
        return false;
      }
    })
    .map((plugin) => {
      const pluginAdminRoute = plugin.admin_route.use_new_show_route
        ? `adminPlugins.show`
        : `adminPlugins.${plugin.admin_route.location}`;
      const pluginConfigNav = configNavForPlugin(plugin.name);

      let pluginNavLinks = [];
      if (pluginConfigNav) {
        if (Array.isArray(pluginConfigNav.links)) {
          pluginNavLinks = [...pluginConfigNav.links];
        }

        if (pluginNavLinks.length) {
          pluginNavLinks = pluginNavLinks
            .map((link) => {
              if (!link.icon) {
                link.icon = "gear";
              }
              if (link.route !== `${pluginAdminRoute}.${plugin.name}`) {
                link.routeModels = [plugin.name];
                return link;
              } else {
                return;
              }
            })
            .compact();
        }
      }

      return {
        name: `admin_plugin_${plugin.admin_route.location}`,
        route: pluginAdminRoute,
        routeModels: plugin.admin_route.use_new_show_route
          ? [plugin.admin_route.location]
          : [],
        label: plugin.admin_route.label,
        text: plugin.humanized_name,
        icon: "gear",
        description: plugin.description,
        links: pluginNavLinks,
      };
    });
}

function installedPluginsLinkKeywords() {
  return (PreloadStore.get("visiblePlugins") || []).map(
    (plugin) => plugin.name
  );
}

export default class AdminSidebarPanel extends BaseCustomSidebarPanel {
  key = ADMIN_PANEL;
  hidden = true;
  displayHeader = true;
  expandActiveSection = true;
  scrollActiveLinkIntoView = true;

  @cached
  get sections() {
    const currentUser = getOwnerWithFallback(this).lookup(
      "service:current-user"
    );
    const siteSettings = getOwnerWithFallback(this).lookup(
      "service:site-settings"
    );
    const store = getOwnerWithFallback(this).lookup("service:store");
    const router = getOwnerWithFallback(this).lookup("service:router");
    const session = getOwnerWithFallback(this).lookup("service:session");

    this.adminSidebarStateManager = getOwnerWithFallback(this).lookup(
      "service:admin-sidebar-state-manager"
    );

    this.adminNavManager = getOwnerWithFallback(this).lookup(
      "service:admin-nav-manager"
    );

    if (!session.get("safe_mode")) {
      const existingPluginLinkNames = this.adminNavManager
        .findSection("plugins")
        .links.map((link) => link.name);
      const pluginLinksToAdd = pluginAdminRouteLinks(router)
        .map((pluginLink) => {
          if (!existingPluginLinkNames.includes(pluginLink.name)) {
            return pluginLink;
          }
        })
        .compact();
      this.adminNavManager.amendLinksToSection("plugins", pluginLinksToAdd);

      this.adminSidebarStateManager.setLinkKeywords(
        "admin_installed_plugins",
        installedPluginsLinkKeywords()
      );
    }

    // Mods cannot access themes
    if (currentUser.admin) {
      store.findAll("theme").then((themes) => {
        this.adminSidebarStateManager.setLinkKeywords(
          "admin_themes_and_components",
          themes.content
            .reject((theme) => theme.component)
            .map((theme) => theme.name)
        );
        this.adminSidebarStateManager.setLinkKeywords(
          "admin_themes_and_components",
          themes.content
            .filter((theme) => theme.component)
            .map((theme) => theme.name)
        );
      });
    }

    if (siteSettings.experimental_form_templates) {
      this.adminNavManager.amendLinksToSection("appearance", [
        {
          name: "admin_customize_form_templates",
          route: "adminCustomizeFormTemplates",
          label: "admin.form_templates.nav_title",
          icon: "list",
        },
      ]);
    }

    if (siteSettings.use_overhauled_theme_color_palette) {
      this.adminNavManager.overrideSectionLink(
        "appearance",
        "admin_color_palettes",
        {
          route: "adminConfig.colorPalettes",
        }
      );
    }

    for (const [sectionName, additionalLinks] of Object.entries(
      additionalAdminSidebarSectionLinks
    )) {
      if (additionalLinks.length) {
        this.adminNavManager.amendLinksToSection(sectionName, additionalLinks);
      }
    }

    return this.adminNavManager.filteredNavMap.map((section) => {
      section.links.forEach((link) => {
        if (link.keywords) {
          this.adminSidebarStateManager.setLinkKeywords(
            link.name,
            i18n(link.keywords).split("|")
          );
        }
      });

      return defineAdminSection(
        section,
        this.adminSidebarStateManager,
        router,
        currentUser
      );
    });
  }

  get searchable() {
    const currentUser = getOwnerWithFallback(this).lookup(
      "service:current-user"
    );
    return currentUser.admin;
  }

  get filterable() {
    const currentUser = getOwnerWithFallback(this).lookup(
      "service:current-user"
    );
    return !currentUser.admin && currentUser.moderator;
  }

  filterNoResultsDescription(filter) {
    const escapedFilter = escapeExpression(filter);

    i18n("sidebar.no_results.description_admin_search", {
      filter: escapedFilter,
    });
  }

  get onSearchClick() {
    getOwnerWithFallback(this)
      .lookup("service:modal")
      .show(this.adminSidebarStateManager.modals.adminSearch);
  }
}
