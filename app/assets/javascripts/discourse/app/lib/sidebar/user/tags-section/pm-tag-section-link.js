import BaseTagSectionLink from "discourse/lib/sidebar/user/tags-section/base-tag-section-link";

export default class PMTagSectionLink extends BaseTagSectionLink {
  get models() {
    return [this.currentUser, this.tagName];
  }

  get route() {
    return "userPrivateMessages.tags.show";
  }
}
