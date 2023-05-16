import { getOwner } from "@ember/application";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

import Section from "discourse/lib/sidebar/section";
import CommunitySection from "discourse/lib/sidebar/community-section";

export default class SidebarCustomSection extends Component {
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
        sectionClass = CommunitySection;
        break;
    }

    return new sectionClass({
      section: this.args.sectionData,
      owner: getOwner(this),
    });
  }
}
