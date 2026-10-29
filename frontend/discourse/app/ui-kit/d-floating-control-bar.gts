import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import type { TrustedHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import bodyClass from "discourse/helpers/body-class";
import DButton from "discourse/ui-kit/d-button";

interface DFloatingControlBarSignature {
  Args: {
    label: string | TrustedHTML;
    saveLabel: string;
    discardLabel: string;
    onSave: () => unknown;
    onDiscard: () => unknown;
    saveButtonId?: string;
  };
  Element: HTMLDivElement;
}

export default class DFloatingControlBar extends Component<DFloatingControlBarSignature> {
  @tracked isSaving = false;

  matchContainerWidth = modifier((element: HTMLElement) => {
    const container = document.getElementById("main-container");
    const resize = () => {
      if (container) {
        element.style.width = `${container.getBoundingClientRect().width}px`;
      }
    };
    resize();

    window.addEventListener("resize", resize);
    return () => window.removeEventListener("resize", resize);
  });

  @action
  async save() {
    this.isSaving = true;

    try {
      await this.args.onSave();
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    {{bodyClass "has-floating-control-bar"}}
    <div
      class="d-floating-control-bar"
      ...attributes
      {{this.matchContainerWidth}}
    >
      <span class="d-floating-control-bar__label">{{@label}}</span>
      <div class="d-floating-control-bar__controls">
        <DButton
          class="btn-default btn-small"
          @action={{@onDiscard}}
          @disabled={{this.isSaving}}
          @translatedLabel={{@discardLabel}}
        />
        <DButton
          class="btn-primary btn-small"
          @action={{this.save}}
          @id={{@saveButtonId}}
          @isLoading={{this.isSaving}}
          @translatedLabel={{@saveLabel}}
        />
      </div>
    </div>
  </template>
}
