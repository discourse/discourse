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

    disableBodyScroll(element);

    return () => {
      enableBodyScroll(element);
    };
  });
}
