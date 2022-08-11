export default class UserMenuBaseItem {
  get className() {}

  get linkHref() {
    throw new Error("not implemented");
  }

  get linkTitle() {
    throw new Error("not implemented");
  }

  get icon() {
    throw new Error("not implemented");
  }

  get label() {
    throw new Error("not implemented");
  }

  get labelClass() {}

  get description() {
    throw new Error("not implemented");
  }

  get descriptionClass() {}

  get topicId() {}
}
