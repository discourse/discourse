import Component from "@glimmer/component";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";

export default class FormTemplateRowItem extends Component {
  @action
  viewTemplate() {
    showModal("admin-customize-form-template-view", {
      admin: true,
      model: this.args.template,
    });
  }
}
