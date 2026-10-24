import Component from "@glimmer/component";
import { service } from "@ember/service";
import { block } from "discourse/blocks";
import { debugHooks } from "discourse/lib/blocks/-internals/debug-hooks";
import type { ChildBlockResult } from "discourse/lib/blocks/-internals/types";
import type Blocks from "discourse/services/blocks";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

interface HeadBlockSignature {
  Args: {
    children: ChildBlockResult[];
  };
}

/**
 * A container block that renders only its first visible child.
 *
 * Use this for prioritized conditional rendering where you want fallback logic:
 * show the first child whose conditions pass, ignore the rest. This is useful
 * for "if X, else if Y, else Z" patterns.
 *
 * ## Debug Visual Overlay Handling
 *
 * Unlike most containers that render all their children, the head block
 * intentionally only renders one child (the first visible one). This means
 * the block must handle the debug visual overlay ghosts itself.
 *
 * The preprocessing phase passes ALL children that passed their conditions,
 * plus ghost blocks for children that failed conditions. Since we choose to
 * not display children 2+, we are responsible for:
 *
 * 1. Rendering ghosts for children that failed their own conditions
 *    (already ghost blocks in `@children`)
 * 2. Converting children that passed conditions but aren't rendered
 *    (because another sibling was first) into ghosts with an explanation
 *
 * This ensures the debug overlay accurately shows why each child is or
 * isn't visible.
 *
 * The system wrapper provides standard BEM classes:
 * - `{outletName}__head` - Standard block class
 *
 * System args (curried at creation time, not passed from parent):
 * - `@outletName` - The outlet identifier this block belongs to
 * - `@outletArgs` - Outlet args available for condition evaluation and access
 *
 * @example
 * ```javascript
 * api.renderBlocks("category-sidebar-blocks", [
 *   {
 *     block: "head",
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
@block("head", {
  container: true,
  displayName: "Conditional",
  icon: "code-branch",
  category: "layout",
  description: "Shows the first child whose conditions match.",
  thumbnail: () => import("discourse/blocks/thumbnails/head"),
})
export default class HeadBlock extends Component<HeadBlockSignature> {
  @service declare blocks: Blocks;

  /**
   * Whether a child matches but loses to an earlier match. Compared by key:
   * child results are rebuilt on every render.
   */
  isSkipped = (child: ChildBlockResult): boolean =>
    !child.isGhost && child.key !== this.firstChild?.key;

  /**
   * Children that passed their conditions and could be rendered.
   */
  get renderableChildren(): ChildBlockResult[] {
    return this.args.children?.filter((c) => !c.isGhost) ?? [];
  }

  /**
   * The one child we actually render (first that passed conditions).
   */
  get firstChild(): ChildBlockResult | undefined {
    return this.renderableChildren[0];
  }

  /**
   * Whether an editing context wants every child shown for direct editing,
   * not only the one that matches.
   */
  get isEditing(): boolean {
    return debugHooks.isEditPresentation;
  }

  /**
   * Converts a passed-over sibling into a ghost with the given reason,
   * for the debug visual overlay.
   */
  ghostify(child: ChildBlockResult, reason: string): ChildBlockResult | null {
    return child.asGhost(reason);
  }

  <template>
    {{#if this.isEditing}}
      {{! Editing: every child stays on the canvas in order, each in the same
          wrapper. A child that matches after the first match shows as a ghost
          explaining why it is skipped. }}
      {{#each @children key="key" as |child|}}
        <div class="d-block-head__child">
          {{#if (this.isSkipped child)}}
            {{#let
              (this.ghostify
                child (i18n "js.blocks.ghost_reasons.head_hidden_tail_hint")
              )
              as |ghostChild|
            }}
              {{#if ghostChild}}
                <ghostChild.Component />
              {{/if}}
            {{/let}}
          {{else}}
            <child.Component />
          {{/if}}
        </div>
      {{/each}}
    {{else if this.blocks.showGhosts}}
      {{!
        When debug mode is enabled, render children in their original order:
        - Ghosts for children that failed conditions
        - The first visible child (actually rendered)
        - Ghosts for children hidden by priority
      }}
      {{#each @children key="key" as |child|}}
        {{#if child.isGhost}}
          {{! Child failed its own conditions - already a ghost }}
          <child.Component />
        {{else if (eq child this.firstChild)}}
          {{! First child that passed conditions - render it }}
          <child.Component />
        {{else}}
          {{! Passed conditions but hidden by priority - convert to ghost }}
          {{#let
            (this.ghostify
              child (i18n "js.blocks.ghost_reasons.head_hidden_tail_hint")
            )
            as |ghostChild|
          }}
            {{#if ghostChild}}
              <ghostChild.Component />
            {{/if}}
          {{/let}}
        {{/if}}
      {{/each}}
    {{else}}
      {{! Normal mode: just render the first visible child }}
      {{#if this.firstChild}}
        <this.firstChild.Component />
      {{/if}}
    {{/if}}
  </template>
}
