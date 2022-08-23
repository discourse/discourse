export default class PMTagSectionLink {
  constructor({ tag, currentUser }) {
    this.tag = tag;
    this.currentUser = currentUser;
  }

  get name() {
    return this.tag.name;
  }

  get models() {
    return [this.currentUser, this.tag.name];
  }

  get route() {
    return "userPrivateMessages.tagsShow";
  }

  get text() {
    return this.tag.name;
  }
}
