import Component from "@glimmer/component";
import Section from "discourse/lib/sidebar/section";
import CommunitySection from "discourse/lib/sidebar/community-section";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/application";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class CustomSection extends Component {
  @service siteSettings;
  @service site;

  @tracked section;

  constructor() {
    super(...arguments);
    this.section = this.#generateSection();
  }

  willDestroy() {
    this.section.teardown?.();
    super.willDestroy();
  }

  @action
  refreshSection() {
    this.section.teardown?.();
    this.section = this.#generateSection;
  }

  get isDesktopDropdownMode() {
    const headerDropdownMode =
      this.siteSettings.navigation_menu === "header dropdown";

    return !this.site.mobileView && headerDropdownMode;
  }

  #generateSection() {
    switch (this.args.sectionConfig.section_type) {
      case "community":
        const systemSection = new CommunitySection({
          section: this.args.sectionConfig,
          owner: getOwner(this),
        });
        return systemSection;
        break;
      default:
        return new Section({
          section: this.args.sectionConfig,
          owner: getOwner(this),
        });
    }
  }
}
