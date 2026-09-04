// @ts-check
import Component from "@glimmer/component";
import { safeHref } from "discourse/lib/safe-href";
import eq from "discourse/truth-helpers/helpers/eq";
import gt from "discourse/truth-helpers/helpers/gt";

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
  /**
   * The first mark to wrap the text with on this recursion level.
   * `undefined` when the marks array is empty.
   *
   * @returns {object|undefined}
   */
  get head() {
    return this.args.marks?.[0];
  }

  /**
   * The remaining marks to apply via recursion, with the head removed.
   * Returns an empty array when the marks list is exhausted.
   *
   * @returns {object[]}
   */
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
        {{! Unknown mark — validator should have caught this; recurse to
            skip the head and apply the rest. }}
        <MarkedText @text={{@text}} @marks={{this.rest}} />
      {{/if}}
    {{else}}
      {{@text}}
    {{/if}}
  </template>
}
