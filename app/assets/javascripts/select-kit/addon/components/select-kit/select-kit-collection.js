import Component from "@ember/component";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import { modifier } from "ember-modifier";
import {
  disableBodyScroll,
  enableBodyScroll,
  locks,
} from "discourse/lib/body-scroll-lock";

@tagName("")
export default class SelectKitCollection extends Component {
  @service site;

  bodyScrollLock = modifier((element) => {
    if (!this.site.mobileView) {
      return;
    }

    const isChildOfLock = locks.some((lock) =>
      lock.targetElement.contains(element)
    );

    if (isChildOfLock) {
      disableBodyScroll(element);
    }

    return () => {
      if (isChildOfLock) {
        enableBodyScroll(element);
      }
    };
  });
}
