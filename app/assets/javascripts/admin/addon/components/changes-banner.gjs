import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import htmlSafe from "discourse/helpers/html-safe";

export default class ChangesBanner extends Component {
  @tracked isSaving = false;

  resizerModifier = modifier((element) => {
    const container = document.getElementById("main-container");
    const resizer = () => this.positionBanner(container, element);
    resizer();

    window.addEventListener("resize", resizer);
    return () => window.removeEventListener("resize", resizer);
  });

  @action
  async save() {
    this.isSaving = true;

    try {
      await this.args.save();
    } finally {
      this.isSaving = false;
    }
  }

  positionBanner(container, element) {
    if (container) {
      const { width } = container.getBoundingClientRect();

      element.style.width = `${width}px`;
    }
  }

  <template>
    <div class="admin-changes-banner" {{this.resizerModifier}}>
      <span class="admin-changes-banner__main-label">{{htmlSafe
          @bannerLabel
        }}</span>
      <div class="controls">
        <DButton
          class="btn-secondary btn-small"
          @action={{@discard}}
          @disabled={{this.isSaving}}
          @translatedLabel={{@discardLabel}}
        />
        <DButton
          class="btn-primary btn-small"
          @action={{this.save}}
          @isLoading={{this.isSaving}}
          @translatedLabel={{@saveLabel}}
        />
      </div>
    </div>
  </template>
}
