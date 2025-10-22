import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

export default class InviteSectionLink extends BaseSectionLink {
  get name() {
    return "invite";
  }

  get route() {
    return "new-invite";
  }

  get title() {
    return i18n("sidebar.sections.community.links.invite.title");
  }

  get text() {
    return i18n(
      `sidebar.sections.community.links.${this.overriddenName.toLowerCase()}.content`,
      { defaultValue: this.overriddenName }
    );
  }

  get shouldDisplay() {
    return !!this.currentUser?.can_invite_to_forum;
  }

  get defaultPrefixValue() {
    return "paper-plane";
  }
}
