import Component from "@ember/component";
import { not, or, reads } from "@ember/object/computed";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import {
  attributeBindings,
  classNameBindings,
  tagName,
} from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";

@tagName("a")
@classNameBindings(":popup-tip", "good", "bad", "lastShownAt::hide")
@attributeBindings("role", "ariaLabel", "tabindex")
export default class PopupInputTip extends Component {
  @service composer;

  tipReason = null;
  tabindex = "0";

  @or("shownAt", "validation.lastShownAt") lastShownAt;
  @reads("validation.failed") bad;
  @not("bad") good;

  @discourseComputed("bad")
  role(bad) {
    if (bad) {
      return "alert";
    }
  }

  @discourseComputed("validation.reason")
  ariaLabel(reason) {
    return reason?.replace(/(<([^>]+)>)/gi, "");
  }

  dismiss() {
    this.set("shownAt", null);
    this.composer.clearLastValidatedAt();
    this.element.previousElementSibling?.focus();
  }

  click() {
    this.dismiss();
  }

  keyDown(event) {
    if (event.key === "Enter") {
      this.dismiss();
    }
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);
    let reason = this.get("validation.reason");
    if (reason) {
      this.set("tipReason", htmlSafe(`${reason}`));
    } else {
      this.set("tipReason", null);
    }
  }
}
