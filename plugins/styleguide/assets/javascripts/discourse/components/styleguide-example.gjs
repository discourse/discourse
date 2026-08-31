import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { warn } from "@ember/debug";
import { action } from "@ember/object";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DHighlightedCode from "discourse/ui-kit/d-highlighted-code";
import { i18n } from "discourse-i18n";
import inlineCode from "discourse/plugins/styleguide/discourse/lib/inline-code";

// A plain counter rather than `guidFor`: `@ember/object/internals` is not resolvable from a
// plugin bundle, and importing it fails the whole bundle at load rather than at use.
let exampleId = 0;

/** What an example demonstrates, when the page is documenting named APIs. */
const KINDS = ["component", "modifier", "service"];

/**
 * One demonstrated capability: a heading, the prose that says what it proves, the live
 * component, and an optional source snippet.
 *
 * `@description`, `@tryThis` and `@note` each accept a plain string or a named block, so prose
 * that needs inline code or a link is expressible without splitting a sentence across translation
 * keys. A block wins over the string when both are supplied.
 *
 * @param {string} title - the capability being shown. Required: it is the card's heading and
 *   it names the source panel's landmark, so omitting it leaves an empty heading behind.
 * @param {number} [headingLevel=2] - heading level for the title, 2 or 3. The default suits an
 *   ungrouped page, where the only heading above is the page's own `h1`. Inside a group, pass 3
 *   so the group's `h2` stays above it — `StyleguideGroup` yields a component already curried
 *   that way.
 * @param {string} [description] - what this example proves. Prefer supplying one: an example
 *   that only shows a widget under a title leaves the reader to infer the point.
 * @param {string} [tryThis] - an instruction the reader can carry out to see it happen.
 *   Omit it when there is nothing to do (a purely visual variation).
 * @param {string} [note] - background prose after the demo: what to notice once it has been
 *   used. Quiet on purpose — the accent bar belongs to `tryThis`, the one thing to act on.
 *   Also accepts a block, for a short list; give a list in that block the class
 *   `styleguide-example__note-list` so it picks up the card's list spacing.
 * @param {string} [code] - the imported source of the example module, revealed by a toggle.
 * @param {string} [kind] - what the example demonstrates: `component`, `modifier` or `service`.
 *   Shown as a label beside the title. For a page documenting named APIs, where a card's title
 *   alone leaves the reader guessing which kind of thing they are looking at. Omit it on a page
 *   that demonstrates appearance rather than an API.
 *
 * Two opt-in classes an example may apply to its own yielded markup:
 * `styleguide-example__result`, for an element the demo writes its output into, inside the
 * default block; and `styleguide-example__note-list`, for a list inside a `note` block. Both
 * are styled as descendants rather than card slots, because yielded content lands inside the
 * slot that yielded it rather than as a grid item of the card.
 *
 * A card may also carry `class="--wide"` to span the full width of a group's grid instead of
 * one column. Put such a card first in its group: the grid places sparsely, so a wide card
 * anywhere else lands flush only when the cards before it happen to fill their row, which a
 * responsive column count cannot promise.
 */
export default class StyleguideExample extends Component {
  @tracked showCode = false;

  codeId = `styleguide-example-code-${(exampleId += 1)}`;

  get headingLevel() {
    return this.args.headingLevel ?? 2;
  }

  get kindLabel() {
    const kind = this.args.kind;
    if (!kind) {
      return;
    }

    warn(
      `<StyleguideExample> was given @kind="${kind}", which is not one of ${KINDS.join(", ")}.`,
      KINDS.includes(kind),
      { id: "styleguide.example-unknown-kind" }
    );

    return KINDS.includes(kind)
      ? i18n(`styleguide.example.kind.${kind}`)
      : null;
  }

  @action
  toggleCode() {
    this.showCode = !this.showCode;
  }

  <template>
    <section class="styleguide-example" ...attributes>
      <div class="styleguide-example__header">
        {{! Two spelled-out branches rather than a computed tag name: only these two levels are
        supported, so naming them is plainer than indirection through a dynamic element. }}
        {{#if (eq this.headingLevel 3)}}
          <h3 class="styleguide-example__title" data-test-example-title>
            {{@title}}
          </h3>
        {{else}}
          <h2 class="styleguide-example__title" data-test-example-title>
            {{@title}}
          </h2>
        {{/if}}

        {{#if this.kindLabel}}
          <span class="styleguide-example__kind">{{this.kindLabel}}</span>
        {{/if}}

        {{#if @code}}
          {{! Icon-only, so the tooltip and the accessible name are set separately. DButton
          builds its aria-label from the ariaLabel argument alone and never from the title
          argument, and a name coming only from a title attribute is a weak one. }}
          <DButton
            @icon="code"
            @title="styleguide.example.toggle_code"
            @ariaLabel="styleguide.example.toggle_code"
            @action={{this.toggleCode}}
            class="btn-flat btn-transparent styleguide-example__code-toggle"
            aria-expanded={{if this.showCode "true" "false"}}
            {{! Only while the region exists — the panel is unmounted when collapsed, and a
            reference to an absent id is an ARIA validity error. }}
            aria-controls={{if this.showCode this.codeId}}
          />
        {{/if}}
      </div>

      {{#if (or @description (has-block "description"))}}
        <p class="styleguide-example__description">
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
        <p class="styleguide-example__try-this">
          <span class="styleguide-example__try-this-label">
            {{i18n "styleguide.example.try_this"}}
          </span>
          {{! One element around the whole instruction, because the row is a flex container:
          prose containing inline code is a mix of text nodes and elements, and each would
          otherwise become its own flex item and be laid out as a separate box, scrambling the
          sentence. }}
          <span class="styleguide-example__try-this-text">
            {{#if (has-block "tryThis")}}
              {{yield to="tryThis"}}
            {{else}}
              {{inlineCode @tryThis}}
            {{/if}}
          </span>
        </p>
      {{/if}}

      <div class="styleguide-example__body">{{yield}}</div>

      {{! The far side of the demo from the instruction: what to notice once it has been used. A
      div rather than a paragraph because a note is as often a short list as a sentence. }}
      {{#if (or @note (has-block "note"))}}
        <div class="styleguide-example__note">
          {{#if (has-block "note")}}
            {{yield to="note"}}
          {{else}}
            {{inlineCode @note}}
          {{/if}}
        </div>
      {{/if}}

      {{#if this.showCode}}
        <div
          class="styleguide-example__code"
          id={{this.codeId}}
          role="region"
          {{! Named after its own example: several panels can be open at once, and landmarks
          sharing one name are indistinguishable in a screen reader's landmark list. }}
          aria-label={{i18n "styleguide.example.code_region" title=@title}}
        >
          <DHighlightedCode @code={{@code}} @lang="javascript" />
        </div>
      {{/if}}
    </section>
  </template>
}
