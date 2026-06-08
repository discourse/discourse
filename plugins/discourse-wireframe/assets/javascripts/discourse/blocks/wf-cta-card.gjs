// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";

/**
 * A composite block: a call-to-action card built from other blocks. Declares a
 * `parts` composition — a heading, a paragraph, and a nested `wf:cta-actions`
 * composite — so a bare `{ block: "wf:cta-card" }` renders the whole card with
 * no children declared.
 *
 * Each part's args can be overridden per instance, keyed by a dot-delimited
 * part-id path: `title` and `body` are direct parts, while `actions.primary`
 * and `actions.secondary` reach the buttons two levels down (inside
 * `wf:cta-actions`). In the editor each part is individually selectable and
 * inline-editable; the card stays a single cohesive block until explicitly
 * detached.
 */
@block("wf:cta-card", {
  displayName: "CTA card",
  category: "Content",
  icon: "bullhorn",
  description:
    "A call-to-action card composed of a heading, text, and buttons.",
  parts: [
    {
      id: "title",
      block: "heading",
      args: { text: "Ready to get started?", level: 2 },
    },
    {
      id: "body",
      block: "paragraph",
      args: { text: "A short sentence that explains the offer." },
    },
    {
      id: "actions",
      block: "wf:cta-actions",
    },
  ],
})
export default class WFCtaCard extends Component {
  <template>
    <div class="wf-cta-card">
      {{#each @children key="key" as |child|}}
        <child.Component />
      {{/each}}
    </div>
  </template>
}
