import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { loadOneboxes } from "discourse/lib/load-oneboxes";
import { cookAsync } from "discourse/lib/text";
import { resolveAllShortUrls } from "pretty-text/upload-short-url";
import { ajax } from "discourse/lib/ajax";

export default class CookText extends Component {
  <template>
    {{! template-lint-disable modifier-name-case }}
    <div
      ...attributes
      {{didUpdate this.buildOneboxes this.cooked}}
      {{didUpdate this.resolveShortUrls this.cooked}}
      {{didUpdate this.calculateOffsetHeight this.cooked}}
    >
      {{this.cooked}}
    </div>
  </template>

  @service siteSettings;
  @tracked cooked = null;

  constructor(owner, args) {
    super(owner, args);
    this.loadCookedText();
  }

  async loadCookedText() {
    const cooked = await cookAsync(this.args.rawText);
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
}
