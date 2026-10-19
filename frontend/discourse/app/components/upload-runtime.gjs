import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";

export default class UploadRuntime extends Component {
  @service uploadRuntime;

  @tracked failed = false;
  @tracked loaded = this.uploadRuntime.loaded;

  constructor() {
    super(...arguments);
    if (!this.loaded) {
      this.#load();
    }
  }

  get showSpinner() {
    return this.args.showSpinner ?? true;
  }

  async #load() {
    try {
      await this.uploadRuntime.load();
      if (!this.isDestroying) {
        this.loaded = true;
      }
    } catch (error) {
      if (!this.isDestroying) {
        this.failed = true;
        popupAjaxError(error);
      }
    }
  }

  <template>
    {{#if this.loaded}}
      {{yield}}
    {{else if this.failed}}
      <DButton @action={{this.uploadRuntime.reload}} @label="refresh" />
    {{else if this.showSpinner}}
      {{dLoadingSpinner}}
    {{/if}}
  </template>
}
