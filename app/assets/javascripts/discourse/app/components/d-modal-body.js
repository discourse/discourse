import Component from "@glimmer/component";
import { scheduleOnce } from "@ember/runloop";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

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

  @tracked fixed = false;

  @action
  didInsert(element) {
    this.appEvents.trigger("modal-body:clearFlash");

    const fixedParent = element.closest(".d-modal.fixed-modal");
    if (fixedParent) {
      this.fixed = true;
      $(fixedParent).modal("show");
    }

    scheduleOnce("afterRender", () => this._afterFirstRender(element));
  }

  @action
  willDestroy() {
    this.appEvents.trigger("modal:body-dismissed");
  }

  _afterFirstRender(element) {
    const maxHeight = this.args.maxHeight;
    if (maxHeight) {
      const maxHeightFloat = parseFloat(maxHeight) / 100.0;
      if (maxHeightFloat > 0) {
        const viewPortHeight = $(window).height();
        element.style.maxHeight =
          Math.floor(maxHeightFloat * viewPortHeight) + "px";
      }
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
      ])
    );
  }
}
