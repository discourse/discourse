import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import type { TrustedHTML } from "@ember/template";
import { waitForPromise } from "@ember/test-waiters";
import { resolveAllShortUrls } from "pretty-text/upload-short-url";
import { ajax } from "discourse/lib/ajax";
import { loadOneboxes } from "discourse/lib/load-oneboxes";
import { cook } from "discourse/lib/text";

/** The site settings this component reads. */
type SiteSettings = {
  max_oneboxes_per_post: number;
  secure_uploads: boolean;
};

interface DCookTextSignature {
  Args: {
    /** The Markdown to cook and render. It is cooked again whenever it changes. */
    rawText: string;

    /** Whether to load the oneboxes in the cooked text. */
    paintOneboxes?: boolean;

    /** The id of the topic the text belongs to, sent with onebox requests. */
    topicId?: number;

    /** The id of the category the text belongs to, sent with onebox requests. */
    categoryId?: number;

    /** Options for resolving the short upload URLs in the cooked text. */
    opts?: object;

    /** Called with the height of the rendered text, in pixels, after it is cooked. */
    onOffsetHeightCalculated?: (offsetHeight: number | undefined) => void;
  };

  Element: HTMLDivElement;
}

export default class DCookText extends Component<DCookTextSignature> {
  @service declare siteSettings: SiteSettings;

  @tracked cooked: TrustedHTML | null = null;

  constructor(owner: Owner, args: DCookTextSignature["Args"]) {
    super(owner, args);
    this.loadCookedText();
  }

  @action
  async loadCookedText() {
    const rawText = this.args.rawText;
    const cooked = await waitForPromise(cook(rawText));
    if (this.isDestroying) {
      return;
    }
    if (this.args.rawText !== rawText) {
      return;
    }
    this.cooked = cooked;
  }

  @action
  calculateOffsetHeight(element: HTMLElement | undefined) {
    if (!this.args.onOffsetHeightCalculated) {
      return;
    }

    return this.args.onOffsetHeightCalculated(element?.offsetHeight);
  }

  @action
  buildOneboxes(element: HTMLElement) {
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
  resolveShortUrls(element: HTMLElement) {
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
