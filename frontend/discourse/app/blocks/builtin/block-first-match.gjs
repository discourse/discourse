import Component from "@glimmer/component";
import { block } from "discourse/blocks/block-outlet";

/**
 * A container block that renders only its first visible child.
 *
 * Use this for prioritized conditional rendering where you want fallback logic:
 * show the first child whose conditions pass, ignore the rest. This is useful
 * for "if X, else if Y, else Z" patterns.
 *
 * The system wrapper provides standard BEM classes:
 * - `block__first-match` - Standard block class
 * - `{outletName}__first-match` - Standard outlet class
 *
 * System args (curried at creation time, not passed from parent):
 * - `@outletName` - The outlet identifier this block belongs to
 * - `@outletArgs` - Outlet args available for condition evaluation and access
 *
 * @example
 * ```javascript
 * api.renderBlocks("category-sidebar-blocks", [
 *   {
 *     block: "first-match",
 *     children: [
 *       // Show support panel for support category
 *       { block: InfoPanel, args: {...}, conditions: [{ type: "route", params: { categorySlug: "support" } }] },
 *       // Show dev panel for dev categories
 *       { block: InfoPanel, args: {...}, conditions: [{ type: "route", params: { categorySlug: "dev" } }] },
 *       // Default fallback (no conditions = always matches)
 *       { block: InfoPanel, args: {...} },
 *     ],
 *   },
 * ]);
 * ```
 */
@block("first-match", {
  container: true,
  description: "Renders only the first child whose conditions pass",
})
export default class FirstMatchBlock extends Component {
  get firstChild() {
    return this.args.children?.[0];
  }

  <template>
    {{#if this.firstChild}}
      <this.firstChild.Component />
    {{/if}}
  </template>
}
