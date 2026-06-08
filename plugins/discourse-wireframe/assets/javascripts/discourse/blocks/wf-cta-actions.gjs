// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";

/**
 * A composite block: a row of two call-to-action buttons. Declares a `parts`
 * composition of two `button-link` blocks, so it renders from arguments alone
 * (no children declared) and each button's args can be overridden per instance
 * by part id (`primary`, `secondary`).
 *
 * The primary button's `variant` is locked: it stays the emphasized button and
 * can't be changed in place — only by detaching the composition.
 *
 * Used together with `wf:cta-card` (which nests this as its `actions` part) to
 * exercise nested, full-depth in-place editing — e.g. the path
 * `actions.primary.label` reaches a button two levels down.
 */
@block("wf:cta-actions", {
  displayName: "CTA actions",
  category: "Layout",
  icon: "arrows-left-right",
  description: "A row of primary and secondary call-to-action buttons.",
  parts: [
    {
      id: "primary",
      block: "button-link",
      args: { label: "Get started", href: "#", variant: "primary" },
      lock: ["variant"],
    },
    {
      id: "secondary",
      block: "button-link",
      args: { label: "Learn more", href: "#", variant: "default" },
    },
  ],
})
export default class WFCtaActions extends Component {
  <template>
    <div class="wf-cta-actions">
      {{#each @children key="key" as |child|}}
        <child.Component />
      {{/each}}
    </div>
  </template>
}
