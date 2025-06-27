import Service, { service } from "@ember/service";
import { cloneJSON } from "discourse/lib/object";
import { ADMIN_NAV_MAP } from "discourse/lib/sidebar/admin-nav-map";

export default class AdminNavManager extends Service {
  @service currentUser;

  #adminNavMap = cloneJSON(ADMIN_NAV_MAP);
  #filteredNavMap = null;

  get filteredNavMap() {
    if (this.#filteredNavMap) {
      return this.#filteredNavMap;
    }

    let navConfig = cloneJSON(this.#adminNavMap);

    if (this.currentUser.admin) {
      return navConfig;
    }

    navConfig.forEach((section) => {
      section.links = section.links.filter((link) => {
        return link.moderator;
      });
    });
    navConfig = navConfig.filter((section) => section.links.length);

    this.#filteredNavMap = navConfig;

    return this.#filteredNavMap;
  }

  findSection(sectionName) {
    this.#guardFilteredNavAccess();

    return this.#adminNavMap.find((section) => section.name === sectionName);
  }

  amendLinksToSection(sectionName, links) {
    this.#guardFilteredNavAccess();

    const section = this.findSection(sectionName);
    if (!section) {
      // eslint-disable-next-line no-console
      console.warn(`[AdminNavManager] Section ${sectionName} not found`);
      return;
    }

    section.links.push(...links);
  }

  overrideSectionLink(sectionName, linkName, newAttrs = {}) {
    this.#guardFilteredNavAccess();

    const section = this.findSection(sectionName);
    const foundLink = section.links.find((link) => link.name === linkName);

    if (foundLink) {
      Object.assign(foundLink, newAttrs);
    } else {
      // eslint-disable-next-line no-console
      console.warn(
        `[AdminNavManager] Link ${linkName} not found in section ${sectionName}`
      );
    }
  }

  #guardFilteredNavAccess() {
    if (this.#filteredNavMap) {
      throw new Error(
        "Cannot call findSection after filteredNavMap has been accessed, admin nav state can only be modified in admin-sidebar.js"
      );
    }
  }
}
