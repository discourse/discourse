// @ts-check
import Component from "@glimmer/component";
import eq from "discourse/truth-helpers/helpers/eq";
import gt from "discourse/truth-helpers/helpers/gt";
import { safeHref } from "../lib/inline-rich-text";

/**
 * Recursive mark wrapper. Walks `@marks` array in order, wrapping the text in
 * the matching tag for each mark (strong / em / link). When the marks array
 * is empty, emits the raw `@text` — Glimmer's text interpolation escapes it,
 * so the renderer can't produce HTML the validator didn't approve.
 *
 * Mark order is canonical (driven by the schema's markSpec order); the
 * recursive structure produces nesting that matches that order.
 */
export default class MarkedText extends Component {
  get head() {
    return this.args.marks?.[0];
  }

  get rest() {
    return this.args.marks?.slice(1) ?? [];
  }

  <template>
    {{#if (gt @marks.length 0)}}
      {{#if (eq this.head.type "strong")}}
        <strong><MarkedText @text={{@text}} @marks={{this.rest}} /></strong>
      {{else if (eq this.head.type "em")}}
        <em><MarkedText @text={{@text}} @marks={{this.rest}} /></em>
      {{else if (eq this.head.type "link")}}
        <a
          href={{safeHref this.head.attrs.href}}
          rel="noopener nofollow ugc"
        ><MarkedText @text={{@text}} @marks={{this.rest}} /></a>
      {{else}}
        {{! Unknown mark — fall through. Validator should have caught this. }}
        <MarkedText @text={{@text}} @marks={{this.rest}} />
      {{/if}}
    {{else}}
      {{@text}}
    {{/if}}
  </template>
}
