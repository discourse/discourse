import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { resolveAllShortUrls } from "pretty-text/upload-short-url";
import { ajax } from "discourse/lib/ajax";
import { loadOneboxes } from "discourse/lib/load-oneboxes";
import { cook } from "discourse/lib/text";

export default class CookText extends Component {
  @service siteSettings;

  @tracked cooked = null;

  constructor(owner, args) {
    super(owner, args);
    this.loadCookedText();
  }

  @action
  async loadCookedText() {
    const cooked = await cook(this.args.rawText);
    this.cooked = cooked;
  }

  @action
  calculateOffsetHeight(element) {
    if (!this.args.onOffsetHeightCalculated) {
      return;
    }

    return this.args.onOffsetHeightCalculated(element?.offsetHeight);
  }

  @action
  buildOneboxes(element) {
    if (this.args.paintOneboxes && this.cooked !== null) {
      loadOneboxes(
        element,
        ajax,
        this.args.topicId,
        this.args.categoryId,
        this.siteSettings.max_oneboxes_per_post,
        false // refresh
      );
    }
  }

  @action
  resolveShortUrls(element) {
    resolveAllShortUrls(ajax, this.siteSettings, element, this.args.opts);
  }

  <template>
    <div
      ...attributes
      {{didUpdate this.buildOneboxes this.cooked}}
      {{didUpdate this.resolveShortUrls this.cooked}}
      {{didUpdate this.calculateOffsetHeight this.cooked}}
      {{didUpdate this.loadCookedText @rawText}}
    >
      {{this.cooked}}
    </div>
  </template>
}
