import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { iconHTML } from "discourse-common/lib/icon-library";
import tippy from "tippy.js";

export default class DiscourseTooltip extends Component {
  <template>
    {{! template-lint-disable modifier-name-case }}
    <div {{didInsert this.initTippy}}>{{yield}}</div>
  </template>

  @service capabilities;

  #tippyInstance;

  willDestroy() {
    super.willDestroy(...arguments);
    this.#tippyInstance.destroy();
  }

  stopPropagation(instance, event) {
    event.preventDefault();
    event.stopPropagation();
  }

  @action
  initTippy(element) {
    this.#tippyInstance = tippy(element.parentElement, {
      content: element,
      interactive: this.args.interactive ?? false,
      trigger: this.capabilities.touch ? "click" : "mouseenter",
      theme: this.args.theme || "d-tooltip",
      arrow: this.args.arrow ? iconHTML("tippy-rounded-arrow") : false,
      placement: this.args.placement || "bottom-start",
      onTrigger: this.stopPropagation,
      onUntrigger: this.stopPropagation,
    });
  }
}
