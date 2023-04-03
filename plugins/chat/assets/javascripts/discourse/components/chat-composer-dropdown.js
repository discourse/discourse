import Component from "@glimmer/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import tippy from "tippy.js";
import { guidFor } from "@ember/object/internals";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { hideOnEscapePlugin } from "discourse/lib/d-popover";
import { isPresent } from "@ember/utils";
import { tracked } from "@glimmer/tracking";

export default class ChatComposerDropdown extends Component {
  @tracked isActive = false;

  @action
  computeIsActive(element, [{ isExpanded }]) {
    if (isPresent(this.args.isActive)) {
      this.isActive = this.args.isActive;
    } else {
      this.isActive = isExpanded;
    }
  }
}
