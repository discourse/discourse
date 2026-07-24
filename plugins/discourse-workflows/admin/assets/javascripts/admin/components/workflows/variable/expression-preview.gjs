import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import ExpressionPreviewContent from "./expression-preview-content";

export default class ExpressionPreview extends Component {
  @service tooltip;

  handleSegmentsChange = () => {
    if (this.args.visible) {
      this.#showTooltip();
    }
  };
  handleVisibilityChange = () => {
    if (this.args.visible) {
      if (this.args.segments?.length) {
        this.#showTooltip();
      }
    } else {
      this.#closeTooltip();
    }
  };
  #tooltipInstance = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.#closeTooltip();
  }

  async #showTooltip() {
    const trigger = this.args.trigger;
    if (!trigger || this.isDestroying || this.isDestroyed) {
      return;
    }

    const segments = this.args.segments;
    if (!segments?.length) {
      this.#closeTooltip();
      return;
    }

    if (this.#tooltipInstance) {
      this.#tooltipInstance.options = {
        ...this.#tooltipInstance.options,
        data: { segments },
      };
      return;
    }

    const input = trigger.querySelector(".workflows-variable-input") || trigger;
    const portalOutletElement = trigger.closest(".d-modal");

    const instance = await this.tooltip.show(input, {
      identifier: "expression-preview",
      component: ExpressionPreviewContent,
      data: { segments },
      placement: "bottom-start",
      fallbackPlacements: ["top-start"],
      interactive: true,
      arrow: false,
      animated: false,
      closeOnEscape: false,
      closeOnClickOutside: false,
      closeOnScroll: false,
      matchTriggerWidth: true,
      maxWidth: 9999,
      offset: 4,
      portalOutletElement,
    });

    if (this.isDestroying || this.isDestroyed) {
      if (instance) {
        this.tooltip.close(instance);
      }
      return;
    }

    this.#tooltipInstance = instance;
  }

  #closeTooltip() {
    if (this.#tooltipInstance) {
      this.tooltip.close(this.#tooltipInstance);
      this.#tooltipInstance = null;
    }
  }

  <template>
    <span
      class="expression-preview__anchor"
      {{didInsert this.handleSegmentsChange}}
      {{didUpdate this.handleSegmentsChange @segments}}
      {{didUpdate this.handleVisibilityChange @visible}}
    ></span>
  </template>
}
