import { cached } from "@glimmer/tracking";
import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import {
  disableBodyScroll,
  enableBodyScroll,
} from "discourse/lib/body-scroll-lock";

@tagName("")
export default class SelectKitCollection extends Component {
  @cached
  get inModal() {
    const element = this.selectKit.mainElement();
    return element.closest(".d-modal");
  }

  @action
  lock(element) {
    if (!this.inModal) {
      return;
    }

    disableBodyScroll(element);
  }

  @action
  unlock(element) {
    enableBodyScroll(element);
  }
}
