import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { empty, equal, notEmpty } from "@ember/object/computed";
import Component from "@glimmer/component";
import deprecated from "discourse-common/lib/deprecated";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";

const ACTION_AS_STRING_DEPRECATION =
  "DButton no longer supports @action as a string. Please refactor to use an closure action instead.";

export default class DButton extends Component {
  @service router;

  @notEmpty("args.icon")
  btnIcon;

  @equal("args.display", "link")
  btnLink;

  @empty("computedLabel")
  noText;

  constructor() {
    super(...arguments);
    if (typeof this.args.action === "string") {
      deprecated(ACTION_AS_STRING_DEPRECATION);
    }
  }

  get forceDisabled() {
    return !!this.args.isLoading;
  }

  get isDisabled() {
    return this.forceDisabled || this.args.disabled;
  }

  get btnType() {
    if (this.args.icon) {
      return this.computedLabel ? "btn-icon-text" : "btn-icon";
    } else if (this.computedLabel) {
      return "btn-text";
    }
  }

  get computedTitle() {
    if (this.args.title) {
      return I18n.t(this.args.title);
    }
    return this.args.translatedTitle;
  }

  get computedLabel() {
    if (this.args.label) {
      return I18n.t(this.args.label);
    }
    return this.args.translatedLabel;
  }

  get computedAriaLabel() {
    if (this.args.ariaLabel) {
      return I18n.t(this.args.ariaLabel);
    }
    if (this.args.translatedAriaLabel) {
      return this.args.translatedAriaLabel;
    }
  }

  get computedAriaExpanded() {
    if (this.args.ariaExpanded === true) {
      return "true";
    }
    if (this.args.ariaExpanded === false) {
      return "false";
    }
  }

  @action
  keyDown(e) {
    if (this.args.onKeyDown) {
      e.stopPropagation();
      this.args.onKeyDown(e);
    } else if (e.key === "Enter") {
      this._triggerAction(e);
    }
  }

  @action
  click(event) {
    return this._triggerAction(event);
  }

  @action
  mouseDown(event) {
    if (this.args.preventFocus) {
      event.preventDefault();
    }
  }

  _triggerAction(event) {
    const { action: actionVal, route, href } = this.args;

    if (actionVal || route || href?.length) {
      if (actionVal) {
        const { actionParam, forwardEvent } = this.args;

        if (typeof actionVal === "string") {
          throw new Error(ACTION_AS_STRING_DEPRECATION);
        } else if (typeof actionVal === "object" && actionVal.value) {
          if (forwardEvent) {
            actionVal.value(actionParam, event);
          } else {
            actionVal.value(actionParam);
          }
        } else if (typeof actionVal === "function") {
          if (forwardEvent) {
            actionVal(actionParam, event);
          } else {
            actionVal(actionParam);
          }
        }
      } else if (route) {
        this.router.transitionTo(route);
      } else if (href?.length) {
        DiscourseURL.routeTo(href);
      }

      event.preventDefault();
      event.stopPropagation();

      return false;
    }
  }
}
