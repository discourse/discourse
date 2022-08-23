export default class PMTagSectionLink {
  constructor({ tagName, currentUser }) {
    this.tagName = tagName;
    this.currentUser = currentUser;
  }

  get name() {
    return this.tagName;
  }

  get models() {
    return [this.currentUser, this.tagName];
  }

  get route() {
    return "userPrivateMessages.tagsShow";
  }

  get text() {
    return this.tagName;
  }
}
