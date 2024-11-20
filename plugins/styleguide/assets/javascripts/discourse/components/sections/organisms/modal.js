import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getLoadedFaker } from "discourse/lib/load-faker";
import { i18n } from "discourse-i18n";

export default class extends Component {
  @tracked inline = true;
  @tracked hideHeader = false;
  @tracked dismissable = true;
  @tracked modalTagName = "div";
  @tracked title = i18n("styleguide.sections.modal.header");
  @tracked body = getLoadedFaker().faker.lorem.lines(5);
  @tracked subtitle = "";
  @tracked flash = "";
  @tracked flashType = "success";

  flashTypes = ["success", "info", "warning", "error"];
  modalTagNames = ["div", "form"];

  @action
  toggleHeader() {
    this.hideHeader = !this.hideHeader;
  }

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
