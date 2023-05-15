import Component from "@glimmer/component";
import Section from "discourse/lib/sidebar/section";
import CommunitySection from "discourse/lib/sidebar/community-section";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/application";
import { action } from "@ember/object";

export default class CustomSection extends Component {
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

  #generateSection() {
    let klass;
    switch (this.args.sectionConfig.section_type) {
      case "community":
        klass = CommunitySection;
        break;
      default:
        klass = Section;
    }

    return new klass({
      section: this.args.sectionConfig,
      owner: getOwner(this),
    });
  }
}
