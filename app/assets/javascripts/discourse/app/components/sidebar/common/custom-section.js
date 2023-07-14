import { getOwner } from "@ember/application";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

import Section from "discourse/lib/sidebar/section";
import AdminCommunitySection from "discourse/lib/sidebar/user/community-section/admin-section";
import CommonCommunitySection from "discourse/lib/sidebar/common/community-section/section";

export default class SidebarCustomSection extends Component {
  @service currentUser;
  @service navigationMenu;
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

  #initializeSection() {
    let sectionClass = Section;

    switch (this.args.sectionData.section_type) {
      case "community":
        sectionClass = this.currentUser?.admin
          ? AdminCommunitySection
          : CommonCommunitySection;
        break;
    }

    return new sectionClass({
      section: this.args.sectionData,
      owner: getOwner(this),
    });
  }
}
