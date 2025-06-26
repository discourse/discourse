import { cached } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { cloneJSON } from "discourse/lib/object";
import { ADMIN_NAV_MAP } from "discourse/lib/sidebar/admin-nav-map";

export default class AdminNavManager extends Service {
  @service currentUser;

  #adminNavMap = cloneJSON(ADMIN_NAV_MAP);

  @cached
  get filteredNavMap() {
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

    return navConfig;
  }

  findSection(sectionName) {
    return this.#adminNavMap.find((section) => section.name === sectionName);
  }

  amendLinksToSection(sectionName, links) {
    const section = this.findSection(sectionName);
    if (!section) {
      // eslint-disable-next-line no-console
      console.warn(`[AdminNavManager] Section ${sectionName} not found`);
      return;
    }

    section.links.push(...links);
  }

  overrideSectionLink(sectionName, linkName, newAttrs = {}) {
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
}
