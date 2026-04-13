import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { cancel, debounce } from "@ember/runloop";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

const VALID_STATES = new Set([
  "valid",
  "invalid",
  "undefined",
  "warning",
  "pending",
  "empty",
]);

const I18N_PREFIX = "discourse_workflows.expression_preview";

function stateLabel(state) {
  return i18n(`${I18N_PREFIX}.${state}`);
}

export default class ExpressionPreview extends Component {
  @service tooltip;

  @tracked segments = [];

  scheduleEvaluation = () => {
    const template = this.args.value;

    if (!template) {
      this.segments = [];
      this.#closeTooltip();
      return;
    }

    this._timer = debounce(this, this.evaluate, 500);
  };
  handleVisibilityChange = () => {
    if (this.args.visible) {
      if (this.segments.length) {
        this.#showTooltip();
      }
    } else {
      this.#closeTooltip();
    }
  };
  #tooltipGeneration = 0;
  _timer = null;
  _tooltipInstance = null;
  _tooltipContent = null;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this._timer);
    this.#closeTooltip();
  }

  #buildResultFragment() {
    if (!this.segments.length) {
      return null;
    }

    const frag = document.createDocumentFragment();

    for (const seg of this.segments) {
      const span = document.createElement("span");
      if (seg.kind === "plaintext") {
        span.className = "expression-preview__plaintext";
        span.textContent = seg.text;
      } else {
        const state = VALID_STATES.has(seg.state) ? seg.state : "pending";
        span.className = `expression-preview__resolved expression-preview__resolved--${state}`;
        if (state === "valid" && seg.text.length > 0) {
          span.textContent = seg.text;
        } else if (state === "valid") {
          span.textContent = stateLabel("empty");
          span.className = `expression-preview__resolved expression-preview__resolved--empty`;
          span.classList.add("expression-preview__resolved--label");
        } else {
          span.textContent = stateLabel(state);
          span.classList.add("expression-preview__resolved--label");
        }
      }
      frag.appendChild(span);
    }

    return frag;
  }

  async evaluate() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    const evaluatedTemplate = this.args.value;
    try {
      const result = await ajax(
        "/admin/plugins/discourse-workflows/expressions/evaluate.json",
        {
          type: "POST",
          data: {
            template: evaluatedTemplate,
            workflow_id: this.args.workflowId,
            node_id: this.args.nodeId,
          },
        }
      );

      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      if (evaluatedTemplate !== this.args.value) {
        return;
      }
      this.segments = result.segments || [];
    } catch {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      this.segments = [];
    }

    this.args.onSegmentsResolved?.(this.segments, evaluatedTemplate);
    if (this.args.visible) {
      await this.#showTooltip();
    }
  }

  async #showTooltip() {
    const gen = ++this.#tooltipGeneration;
    const trigger = this.args.trigger;
    if (!trigger || this.isDestroying || this.isDestroyed) {
      return;
    }

    const resultFragment = this.#buildResultFragment();
    if (!resultFragment) {
      this.#closeTooltip();
      return;
    }

    // Update in-place if tooltip already exists to avoid flicker
    if (this._tooltipInstance && this._tooltipContent) {
      const existing = this._tooltipContent.querySelector(
        ".expression-preview__result"
      );
      if (existing) {
        existing.replaceChildren(resultFragment);
        return;
      }
    }

    this.#closeTooltip();

    const input = trigger.querySelector(".workflows-variable-input") || trigger;
    const portalOutletElement = trigger.closest(".d-modal");

    const el = document.createElement("div");
    el.className = "expression-preview";
    el.tabIndex = -1;

    const label = document.createElement("span");
    label.className = "expression-preview__label";
    label.textContent = i18n(`${I18N_PREFIX}.result`);
    el.appendChild(label);

    const result = document.createElement("span");
    result.className = "expression-preview__result";
    result.appendChild(resultFragment);
    el.appendChild(result);

    const instance = await this.tooltip.show(input, {
      identifier: "expression-preview",
      content: el,
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

    if (
      this.isDestroying ||
      this.isDestroyed ||
      gen !== this.#tooltipGeneration
    ) {
      if (instance) {
        this.tooltip.close(instance);
      }
      return;
    }

    this._tooltipInstance = instance;
    this._tooltipContent = el;
  }

  #closeTooltip() {
    if (this._tooltipInstance) {
      this.tooltip.close(this._tooltipInstance);
      this._tooltipInstance = null;
      this._tooltipContent = null;
    }
  }

  <template>
    <span
      class="expression-preview-anchor"
      {{didInsert this.scheduleEvaluation}}
      {{didUpdate this.scheduleEvaluation @value}}
      {{didUpdate this.handleVisibilityChange @visible}}
    ></span>
  </template>
}
