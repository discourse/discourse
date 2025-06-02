import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import DButton from "discourse/components/d-button";
import htmlSafe from "discourse/helpers/html-safe";

export default class ChangesBanner extends Component {
  @tracked isSaving = false;
  _resizer = null;

  @action
  async save() {
    this.isSaving = true;

    try {
      await this.args.save();
    } finally {
      this.isSaving = false;
    }
  }

  @action
  setupResizeObserver(element) {
    const container = document.getElementById("main-container");
    this._resizer = () => this.positionBanner(container, element);

    this._resizer();

    this._resizeObserver = window.addEventListener("resize", this._resizer);
  }

  @action
  teardownResizeObserver() {
    window.removeEventListener("resize", this._resizer);
  }

  positionBanner(container, element) {
    if (container) {
      const { width } = container.getBoundingClientRect();

      element.style.width = `${width}px`;
    }
  }

  <template>
    <div
      class="admin-changes-banner"
      {{didInsert this.setupResizeObserver}}
      {{willDestroy this.teardownResizeObserver}}
    >
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
