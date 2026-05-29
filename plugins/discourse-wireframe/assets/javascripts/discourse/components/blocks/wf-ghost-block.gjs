// @ts-check
import Component from "@glimmer/component";
import { FAILURE_TYPE } from "discourse/lib/blocks/-internals/patterns";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Editor-native placeholder for a block that didn't render — usually
 * because its conditions evaluated false, but also covers
 * unknown-block (the registry can't resolve the name) and
 * no-visible-children (a container whose children were all hidden).
 *
 * Unlike the dev-tools `GhostBlock` (which is a small badge with a
 * hover tooltip — built for diagnostic overlays), this component
 * renders a faded silhouette the author can click into. Selection,
 * the inspector, drag, and delete all flow through the same chrome
 * wrapper that wraps real blocks, so the author can fix the failing
 * condition / args / id in place.
 *
 * Receives the curry args from `api-initializers/wireframe.js`:
 *   - blockName, blockId (string)
 *   - failureType (one of FAILURE_TYPE.*)
 *   - failureReason (optional override message)
 *   - ghostChildren (array of `{Component, key}` ghost descriptors) —
 *     populated for containers that failed with `NO_VISIBLE_CHILDREN`
 *     by `installGhostChildrenCreator`. Each child has already been
 *     wrapped in chrome via `BLOCK_DEBUG`, so rendering it here just
 *     means invoking its `Component`.
 *   - blockArgs, conditions (for context — the inspector reads
 *     these directly via the selection plumbing, so we don't need
 *     to render them inside the ghost itself).
 */
export default class WFGhostBlock extends Component {
  /**
   * The icon to display in the ghost header, picked per failure type so
   * the author can quickly tell whether they're looking at a missing
   * block, a condition gate, an empty container, etc.
   *
   * @returns {string}
   */
  get iconName() {
    switch (this.args.failureType) {
      case FAILURE_TYPE.OPTIONAL_MISSING:
        return "circle-question";
      case FAILURE_TYPE.UNKNOWN_BLOCK:
        return "triangle-exclamation";
      case FAILURE_TYPE.NO_VISIBLE_CHILDREN:
        return "circle-dashed";
      default:
        return "eye-slash";
    }
  }

  /**
   * Whether to paint the ghost with the error treatment (danger-red).
   *
   * UNKNOWN_BLOCK is a genuine authoring error (typo, renamed /
   * removed registration), so it gets the danger-red treatment.
   * CONDITION_FAILED is intentional gating — the author set the
   * condition; staying neutral keeps the canvas calm.
   * NO_VISIBLE_CHILDREN can be either, but the actual cause is
   * visible inside the container's child ghosts; keeping the
   * container itself neutral avoids double-painting.
   *
   * @returns {boolean}
   */
  get isError() {
    return this.args.failureType === FAILURE_TYPE.UNKNOWN_BLOCK;
  }

  /**
   * Human-readable explanation shown under the ghost's header.
   * Author-supplied `failureReason` overrides the canned message so
   * containers (e.g. the head block) can surface their own reason.
   *
   * @returns {string}
   */
  get hintMessage() {
    if (this.args.failureReason) {
      return this.args.failureReason;
    }
    switch (this.args.failureType) {
      case FAILURE_TYPE.OPTIONAL_MISSING:
        return i18n("wireframe.canvas.ghost.optional_missing");
      case FAILURE_TYPE.UNKNOWN_BLOCK:
        return i18n("wireframe.canvas.ghost.unknown_block");
      case FAILURE_TYPE.NO_VISIBLE_CHILDREN:
        return i18n("wireframe.canvas.ghost.no_visible_children");
      default:
        return i18n("wireframe.canvas.ghost.condition_failed");
    }
  }

  <template>
    <div class={{dConcatClass "wf-ghost-block" (if this.isError "--error")}}>
      <div class="wf-ghost-block__header">
        <span class="wf-ghost-block__icon" aria-hidden="true">
          {{dIcon this.iconName}}
        </span>
        <span class="wf-ghost-block__name">{{@blockName}}</span>
        {{#if @blockId}}
          <span class="wf-ghost-block__id">#{{@blockId}}</span>
        {{/if}}
      </div>
      <p class="wf-ghost-block__hint">{{this.hintMessage}}</p>
      {{#if @ghostChildren.length}}
        <div class="wf-ghost-block__children">
          {{#each @ghostChildren key="key" as |child|}}
            <child.Component />
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}
