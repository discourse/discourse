import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import DButton from "discourse/components/d-button";
import FullscreenCodeModal from "discourse/components/modal/fullscreen-code";
import { bind } from "discourse/lib/decorators";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { iconHTML } from "discourse/lib/icon-library";
import discourseLater from "discourse/lib/later";
import Mobile from "discourse/lib/mobile";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

// Use to attach copy/fullscreen buttons to a block of code, either
// within the post stream or for a regular element that contains
// a pre > code HTML structure.
//
// Usage (post):
//
// const cb = new CodeblockButtons({
//   showFullscreen: true,
//   showCopy: true,
// });
// cb.attachToPost(post, postElement);
//
// Usage (generic):
//
// const cb = new CodeblockButtons({
//   showFullscreen: true,
//   showCopy: true,
// });
// cb.attachToGeneric(element);
//
// Make sure to run .cleanup() on the instance once you are done to
// remove click events.

const DEFAULT_COPY_ICON = "copy";
const ACTIVE_COPY_ICON = "check";
const DEFAULT_COPY_LABEL = "copy";
const ACTIVE_COPY_LABEL = "copied";

class Test extends Component {
  @service modal;

  copyBtnState = new TrackedObject({
    label: DEFAULT_COPY_LABEL,
    icon: DEFAULT_COPY_ICON,
  });

  @action
  expand() {
    this.modal.show(FullscreenCodeModal, {
      model: {
        lang: this.args.data.lang,
        code: this.args.data.code,
      },
    });
  }

  @action
  copy() {
    this.copyBtnState.label = ACTIVE_COPY_LABEL;
    this.copyBtnState.icon = ACTIVE_COPY_ICON;

    clipboardCopy(this.args.data.code);

    discourseLater(() => {
      this.copyBtnState.label = DEFAULT_COPY_LABEL;
      this.copyBtnState.icon = DEFAULT_COPY_ICON;
    }, 3000);
  }

  <template>
    <div class="code-block__header">
      {{#if @data.path}}
        <span class="code-block__path">{{@data.path}}</span>
      {{else}}
        <span class="code-block__path">{{@data.lang}}</span>
      {{/if}}

      <div class="code-block__header-actions">

        {{#if @data.showCopy}}
          <DButton
            @icon={{this.copyBtnState.icon}}
            class="btn-small btn-transparent code-block__copy-btn"
            @label={{concat "copy_codeblock." this.copyBtnState.label}}
            @action={{this.copy}}
          />
        {{/if}}

        {{#if @data.showFullscreen}}
          <DButton
            @icon="discourse-expand"
            class="btn-small btn-transparent code-block__expand-btn"
            @label="copy_codeblock.fullscreen"
            @action={{this.expand}}
          />
        {{/if}}
      </div>
    </div>
  </template>
}

export default class CodeblockButtons {
  constructor(opts = {}) {
    opts = Object.assign(
      {
        showFullscreen: true,
        showCopy: true,
      },
      opts
    );

    this.showFullscreen = opts.showFullscreen;
    this.showCopy = opts.showCopy;
  }

  _getCodeBlocks(element) {
    return element.querySelectorAll(
      ":scope > pre[data-code-wrap], :scope :not(article):not(blockquote) > pre[data-code-wrap]"
    );
  }

  attachToPost(postElement, helper) {
    let codeBlocks = this._getCodeBlocks(postElement);
    [...codeBlocks].forEach((block) => {
      const code = block
        .querySelector("code")
        .innerText.replace(
          /[\f\v\u00a0\u1680\u2000-\u200a\u202f\u205f\u3000\ufeff]/g,
          " "
        )
        .trim();

      helper.renderGlimmer(block, Test, {
        lang: block.dataset.codeWrap,
        path: block.dataset.codePath,
        lines: block.dataset.codeLines,
        numbers: block.dataset.codeNumbers === "true",
        code,
        showFullscreen: this.showFullscreen,
        showCopy: this.showCopy,
      });
    });
  }
}
