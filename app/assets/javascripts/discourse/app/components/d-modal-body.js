// Remove when legacy modals are dropped (deprecation: discourse.modal-controllers)

import Component from "@glimmer/component";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { DEBUG } from "@glimmer/env";

const LEGACY_ERROR =
  "d-modal-body should only be used inside a legacy controller-based d-modal. https://meta.discourse.org/t/268057";

function pick(object, keys) {
  const result = {};
  for (const key of keys) {
    if (key in object) {
      result[key] = object[key];
    }
  }
  return result;
}

@disableImplicitInjections
export default class DModalBody extends Component {
  @service appEvents;
  @service modal;

  @tracked fixed = false;

  @action
  didInsert(element) {
    if (element.closest(".d-modal:not(.d-modal-legacy)")) {
      // eslint-disable-next-line no-console
      console.error(LEGACY_ERROR);
      if (DEBUG) {
        throw new Error(LEGACY_ERROR);
      }
    }

    this.appEvents.trigger("modal-body:clearFlash");

    const fixedParent = element.closest(".d-modal.fixed-modal");
    if (fixedParent) {
      this.fixed = true;
      $(fixedParent).modal("show");
      this.modal.hidden = false;
    }

    this.appEvents.trigger(
      "modal:body-shown",
      pick(this.args, [
        "title",
        "rawTitle",
        "fixed",
        "subtitle",
        "rawSubtitle",
        "submitOnEnter",
        "dismissable",
        "headerClass",
        "modalClass",
        "titleAriaElementId",
      ])
    );
  }

  @action
  willDestroy() {
    this.appEvents.trigger("modal:body-dismissed");
  }
}
