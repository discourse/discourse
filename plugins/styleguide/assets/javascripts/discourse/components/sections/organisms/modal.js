import { action } from "@ember/object";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";

export default class extends Component {
  @tracked inline = true;
  @tracked dismissable = true;
  @tracked modalTagName = "div";
  @tracked title = I18n.t("styleguide.sections.modal.header");
  @tracked body = this.args.dummy.shortLorem;
  @tracked subtitle = "";
  @tracked flash = "";
  @tracked flashType = "success";

  flashTypes = ["success", "info", "warning", "error"];
  modalTagNames = ["div", "form"];

  @action
  toggleInline() {
    this.inline = !this.inline;
    if (!this.inline) {
      // Make sure there is a way to dismiss the modal
      this.dismissable = true;
    }
  }

  @action
  toggleDismissable() {
    this.dismissable = !this.dismissable;
    if (!this.dismissable) {
      // Make sure there is a way to dismiss the modal
      this.inline = true;
    }
  }

  @action
  toggleShowFooter() {
    this.showFooter = !this.showFooter;
  }
}
