/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { computed } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import {
  attributeBindings,
  classNameBindings,
  tagName,
} from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";

@tagName("a")
@classNameBindings(":popup-tip", "good", "bad", "lastShownAt::hide")
@attributeBindings("role", "ariaLabel", "tabindex")
export default class PopupInputTip extends Component {
  @service composer;

  tipReason = null;
  tabindex = "0";

  @tracked _badOverride;

  @computed("shownAt", "validation.lastShownAt")
  get lastShownAt() {
    return this.shownAt || this.validation?.lastShownAt;
  }

  @computed("validation.failed")
  get bad() {
    if (this._badOverride !== undefined) {
      return this._badOverride;
    }
    return this.validation?.failed;
  }

  set bad(value) {
    this._badOverride = value;
  }

  @computed("bad")
  get good() {
    return !this.bad;
  }

  @computed("bad")
  get role() {
    if (this.bad) {
      return "alert";
    }
  }

  @computed("validation.reason")
  get ariaLabel() {
    return this.validation?.reason?.replace(/(<([^>]+)>)/gi, "");
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

  <template>{{this.tipReason}} {{icon "circle-xmark"}}</template>
}
