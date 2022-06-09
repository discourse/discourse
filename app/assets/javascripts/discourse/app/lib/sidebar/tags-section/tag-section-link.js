export default class TagSectionLink {
  constructor({ tag }) {
    this.tag = tag;
  }

  get name() {
    return this.tag;
  }

  get model() {
    return this.tag;
  }

  get currentWhen() {
    return "tag.show tag.showNew tag.showUnread tag.showTop";
  }

  get route() {
    return "tag.show";
  }

  get text() {
    return this.tag;
  }
}
