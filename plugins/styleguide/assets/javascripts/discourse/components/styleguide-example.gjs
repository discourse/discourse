import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DHighlightedCode from "discourse/ui-kit/d-highlighted-code";
import { i18n } from "discourse-i18n";
import inlineCode from "discourse/plugins/styleguide/discourse/helpers/inline-code";

// A plain counter rather than `guidFor`: `@ember/object/internals` is not resolvable from a
// plugin bundle, and importing it fails the whole bundle at load rather than at use.
let exampleId = 0;

/**
 * One demonstrated capability: a heading, the prose that says what it proves, the live
 * component, and an optional source snippet.
 *
 * `@description` and `@tryThis` each accept a plain string or a named block, so prose that
 * needs inline code or a link is expressible without splitting a sentence across translation
 * keys. A block wins over the string when both are supplied.
 *
 * @param {string} [title] - the capability being shown.
 * @param {string} [description] - what this example proves. Prefer supplying one: an example
 *   that only shows a widget under a title leaves the reader to infer the point.
 * @param {string} [tryThis] - an instruction the reader can carry out to see it happen.
 *   Omit it when there is nothing to do (a purely visual variation).
 * @param {string} [note] - background prose after the demo: what to notice once it has been
 *   used. Quiet on purpose — the accent bar belongs to `tryThis`, the one thing to act on.
 *   Also accepts a block, for a short list.
 * @param {string} [result] - live output the demo produces, such as a counter that moves as the
 *   reader interacts. Emphasised rather than quiet, because watching it change IS the example.
 * @param {string} [code] - a source snippet, revealed by a toggle. Optional, because it is a
 *   hand-maintained copy of the template and drifts from it.
 * @param {unknown} [initialValue] - seeds the value yielded to the default block.
 */
export default class StyleguideExample extends Component {
  @tracked value = null;
  @tracked showCode = false;

  codeId = `styleguide-example-code-${(exampleId += 1)}`;

  constructor() {
    super(...arguments);
    this.value = this.args.initialValue;
  }

  @action
  toggleCode() {
    this.showCode = !this.showCode;
  }

  <template>
    <section class="styleguide-example" ...attributes>
      <div class="styleguide-example__header">
        <h3 class="styleguide-example__title" data-test-example-title>
          {{@title}}
        </h3>

        {{#if @code}}
          {{! Icon-only, so both the tooltip and the accessible name are set explicitly. The
          button derives no name from its tooltip, and a tooltip alone is a weak one. }}
          <DButton
            @icon="code"
            @title="styleguide.example.toggle_code"
            @ariaLabel="styleguide.example.toggle_code"
            @action={{this.toggleCode}}
            class="btn-flat btn-transparent styleguide-example__code-toggle"
            aria-expanded={{if this.showCode "true" "false"}}
            aria-controls={{this.codeId}}
          />
        {{/if}}
      </div>

      {{#if (or @description (has-block "description"))}}
        <p
          class="styleguide-example__description"
          data-test-example-description
        >
          {{#if (has-block "description")}}
            {{yield to="description"}}
          {{else}}
            {{inlineCode @description}}
          {{/if}}
        </p>
      {{/if}}

      {{! Placed above the demo so a keyboard or screen-reader user meets the instruction
      before the control it applies to. }}
      {{#if (or @tryThis (has-block "tryThis"))}}
        <p class="styleguide-example__try-this" data-test-example-try-this>
          <span class="styleguide-example__try-this-label">
            {{i18n "styleguide.example.try_this"}}
          </span>
          {{#if (has-block "tryThis")}}
            {{yield to="tryThis"}}
          {{else}}
            {{inlineCode @tryThis}}
          {{/if}}
        </p>
      {{/if}}

      <section class="styleguide-example__body">{{yield this.value}}</section>

      {{! The far side of the demo from the instruction: what to notice once it has been used. A
      div rather than a paragraph because a note is as often a short list as a sentence. }}
      {{#if (or @note (has-block "note"))}}
        <div class="styleguide-example__note" data-test-example-note>
          {{#if (has-block "note")}}
            {{yield to="note"}}
          {{else}}
            {{inlineCode @note}}
          {{/if}}
        </div>
      {{/if}}

      {{! Distinct from a note: a note is prose the reader takes in passively, while this is
      output the component produced. Emphasising it is the point — the reader is meant to watch
      it change — but it is not an instruction, so it does not wear the instruction's mark. }}
      {{#if (or @result (has-block "result"))}}
        <output class="styleguide-example__result" data-test-example-result>
          {{#if (has-block "result")}}
            {{yield to="result"}}
          {{else}}
            {{@result}}
          {{/if}}
        </output>
      {{/if}}

      {{#if this.showCode}}
        {{! Last, not between the description and the instruction where it used to sit. Cards
        in a row share their rows, so a code block in the middle of one card pushes the
        control of every card beside it down the page the moment it is opened. At the end it
        only makes the row taller and nothing inside any card moves.

        Highlighted as XML rather than as Handlebars, which is absent from the default
        highlighted-languages bundle and would render with no highlighting at all. Template
        markup reads correctly as XML; the JavaScript grammar used previously did not. }}
        <div
          class="styleguide-example__code"
          id={{this.codeId}}
          role="region"
          aria-label={{i18n "styleguide.example.code_region"}}
        >
          <DHighlightedCode @code={{@code}} @lang="xml" />
        </div>
      {{/if}}
    </section>
  </template>
}
