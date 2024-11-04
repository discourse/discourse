import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import I18n from "discourse-i18n";

export default class InviteSectionLink extends BaseSectionLink {
  get name() {
    return "invite";
  }

  get route() {
    return "new-invite";
  }

  get title() {
    return I18n.t("sidebar.sections.community.links.invite.content");
  }

  get text() {
    return I18n.t(
      `sidebar.sections.community.links.${this.overridenName.toLowerCase()}.content`,
      { defaultValue: this.overridenName }
    );
  }

  get shouldDisplay() {
    return !!this.currentUser?.can_invite_to_forum;
  }

  get defaultPrefixValue() {
    return "paper-plane";
  }
}
