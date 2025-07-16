import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { i18n } from "discourse-i18n";

export default class AssignUser extends Component {
  @service taskActions;

  model = new TrackedObject(this.args.model);

  // `submit` property will be mutated by the `AssignUserForm` component
  formApi = {
    submit() {},
  };

  get title() {
    let i18nSuffix;

    switch (this.model.targetType) {
      case "Post":
        i18nSuffix = "_post_modal";
        break;
      case "Topic":
        i18nSuffix = "_modal";
        break;
    }

    return i18n(
      `discourse_assign.assign${i18nSuffix}.${
        this.model.reassign ? "reassign_title" : "title"
      }`
    );
  }

  @action
  async onSubmit() {
    this.args.closeModal();
    await this.taskActions.assign(this.model);
  }
}
