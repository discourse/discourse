import Component from "@ember/component";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import { modifier } from "ember-modifier";
import {
  disableBodyScroll,
  enableBodyScroll,
} from "discourse/lib/body-scroll-lock";

@tagName("")
export default class SelectKitCollection extends Component {
  @service site;

  bodyScrollLock = modifier((element) => {
    if (!this.site.mobileView) {
      return;
    }

    // when opened a modal will disable all scroll but itself
    // this code is whitelisting the collection to ensure it can be scrolled in this case
    // however we only want to do this if the modal is open to avoid breaking the scroll on the page
    // eg: opening a combobox under a topic shouldn't prevent you to scroll the topic page
    const isModalOpen =
      document.documentElement.classList.contains("modal-open");
    if (!isModalOpen) {
      return;
    }

    disableBodyScroll(element);

    return () => {
      enableBodyScroll(element);
    };
  });
}
