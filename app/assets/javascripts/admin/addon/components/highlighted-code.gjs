import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import FullscreenCodeModal from "discourse/components/modal/fullscreen-code";
import concatClass from "discourse/helpers/concat-class";
import highlightSyntax from "discourse/lib/highlight-syntax";
import discourseLater from "discourse/lib/later";
import { clipboardCopy } from "discourse/lib/utilities";

class NumbersLayer extends Component {
  <template>
    <AuxiliaryLayer
      @lineNumbers={{@lineNumbers}}
      @highlightedLines={{@highlightedLines}}
      ...attributes
      as |ln|
    ><span class="number">{{ln}}</span></AuxiliaryLayer>
  </template>
}

class BackgroundLayer extends Component {
  <template>
    <AuxiliaryLayer
      @lineNumbers={{@lineNumbers}}
      @highlightedLines={{@highlightedLines}}
      ...attributes
    >&nbsp;</AuxiliaryLayer>
  </template>
}

class AuxiliaryLayer extends Component {
  newline = "\n";

  @action
  isHighlightedLine(ln) {
    return this.args.highlightedLines && this.args.highlightedLines.has(ln);
  }

  <template>
    <pre aria-hidden={{true}} ...attributes>{{~#each @lineNumbers as |ln|}}<span
          class={{concatClass
            "highlighted-code__line-placeholder"
            (if (this.isHighlightedLine ln) "-highlighted" "-not-highlighted ")
          }}
        >{{yield ln}}</span>{{this.newline}}{{/each~}}</pre>
  </template>
}

const DEFAULT_COPY_ICON = "copy";
const ACTIVE_COPY_ICON = "check";
const DEFAULT_COPY_LABEL = "copy";
const ACTIVE_COPY_LABEL = "copied";

export default class HighlightedCode extends Component {
  @service session;
  @service siteSettings;
  @service modal;

  copyBtnState = new TrackedObject({
    label: DEFAULT_COPY_LABEL,
    icon: DEFAULT_COPY_ICON,
  });

  highlight = modifier(async (element) => {
    const code = document.createElement("code");
    code.classList.add(`lang-${this.args.lang}`);
    code.textContent = this.args.code;

    element.replaceChildren(code);
    await highlightSyntax(element, this.siteSettings, this.session);
  });

  @action
  expand() {
    this.modal.show(FullscreenCodeModal, {
      model: {
        lang: this.args.lang,
        code: this.args.code,
        path: this.args.path,
        highlightedLines: this.args.highlightedLines,
        numbers: this.args.numbers,
      },
    });
  }

  @action
  copy() {
    this.copyBtnState.label = ACTIVE_COPY_LABEL;
    this.copyBtnState.icon = ACTIVE_COPY_ICON;

    clipboardCopy(this.args.code);

    discourseLater(() => {
      this.copyBtnState.label = DEFAULT_COPY_LABEL;
      this.copyBtnState.icon = DEFAULT_COPY_ICON;
    }, 3000);
  }

  get lineNumbers() {
    return this.args.code.split("\n").map((_, index) => index + 1);
  }

  get highlightedLines() {
    return this.parseLineRanges(this.args.highlightedLines);
  }

  get highlightLines() {
    return this.highlightedLines && this.args.highlightedLines?.length;
  }

  @action
  parseLineRanges(lineRangesRaw) {
    if (lineRangesRaw === undefined) {
      return null;
    }

    return new Set(lineRangesRaw.split(",").flatMap(this.parseLineRange));
  }

  @action
  parseLineRange(lineRangeRaw) {
    let [begin, end] = lineRangeRaw.trim().split("-");
    if (!end) {
      end = begin;
    }

    return this.range(Number(begin), Number(end) + 1);
  }

  range(start, end) {
    const result = [];
    for (let i = start; i < end; i++) {
      result.push(i);
    }
    return result;
  }

  <template>
    <div class="highlighted-code">
      <div class="highlighted-code__header">
        {{#if @path}}
          <span class="highlighted-code__path">{{@path}}</span>
        {{else}}
          <span class="highlighted-code__path">{{@lang}}</span>
        {{/if}}

        <div class="highlighted-code__header-actions">
          {{#if @showCopy}}
            <DButton
              @icon={{this.copyBtnState.icon}}
              class="btn-small btn-transparent highlighted-code__copy-btn"
              @label={{concat "copy_codeblock." this.copyBtnState.label}}
              @action={{this.copy}}
            />
          {{/if}}

          {{#if @showFullscreen}}
            <DButton
              @icon="discourse-expand"
              class="btn-small btn-transparent highlighted-code__expand-btn"
              @label="copy_codeblock.fullscreen"
              @action={{this.expand}}
            />
          {{/if}}
          {{#if @close}}
            <DButton
              @icon="xmark"
              class="btn-small btn-transparent highlighted-code__close-btn"
              @action={{@close}}
            />
          {{/if}}
        </div>
      </div>

      <div class="highlighted-code__body">
        {{#if this.highlightLines}}
          <div class="highlighted-code__gutter">
            <NumbersLayer
              @lineNumbers={{this.lineNumbers}}
              class="highlighted-code__numbers-layer"
            />
          </div>
        {{/if}}

        <div class="highlighted-code__editor">
          <BackgroundLayer
            @lineNumbers={{this.lineNumbers}}
            @highlightedLines={{this.highlightedLines}}
            class="highlighted-code__background-layer"
          />

          <pre {{this.highlight}} class="highlighted-code__code"></pre>
        </div>
      </div>
    </div>
  </template>
}
