import Component from "@glimmer/component";
import { customSections as sidebarCustomSections } from "discourse/lib/sidebar/custom-sections";
import { getOwner, setOwner } from "@ember/application";
import { inject as service } from "@ember/service";

export default class SidebarUserSections extends Component {
  @service siteSettings;
  @service currentUser;
  @service site;

  customSections;

  constructor() {
    super(...arguments);
    this.customSections = this._customSections;
  }

  get _customSections() {
    return sidebarCustomSections.map((customSection) => {
      const section = new customSection({ sidebar: this });
      setOwner(section, getOwner(this));
      return section;
    });
  }

  get enableMessagesSection() {
    return this.currentUser?.can_send_private_messages;
  }
}
