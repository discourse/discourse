import { getOwner } from "@ember/application";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

import Section from "discourse/lib/sidebar/section";
import CommunitySection from "discourse/lib/sidebar/community-section";

export default class SidebarCustomSection extends Component {
  @service site;
  @service siteSettings;

  @tracked section;

  constructor() {
    super(...arguments);
    this.section = this.#initializeSection();
  }

  willDestroy() {
    this.section.teardown?.();
    super.willDestroy();
  }

  get isDesktopDropdownMode() {
    const headerDropdownMode =
      this.siteSettings.navigation_menu === "header dropdown";

    return !this.site.mobileView && headerDropdownMode;
  }

  #initializeSection() {
    let sectionClass = Section;

    switch (this.args.sectionData.section_type) {
      case "community":
        sectionClass = CommunitySection;
        break;
    }

    return new sectionClass({
      section: this.args.sectionData,
      owner: getOwner(this),
    });
  }
}
