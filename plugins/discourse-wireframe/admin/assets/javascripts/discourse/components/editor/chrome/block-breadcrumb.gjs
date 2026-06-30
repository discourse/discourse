// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Sticky breadcrumb pinned to the bottom of the editor canvas. Shows
 * the path from the current outlet down through any nested container
 * blocks to the selected block. Each segment is clickable to re-select
 * that ancestor — a quick way to jump up the tree without
 * clicking-through nested chromes.
 *
 * Hidden when nothing is selected.
 *
 * The path itself is derived in the selection service via
 * `selectedBlockAncestry`, which walks the live layout from the
 * outlet root to the selected key and returns an array of
 * `{key, blockName, displayName, isOutlet, outletName}` segments.
 */
export default class BlockBreadcrumb extends Component {
  @service wireframeSelection;

  /**
   * Ordered list of ancestry segments from the outlet root down to the
   * selected block. Each segment carries the data needed to render and
   * to re-select that ancestor.
   *
   * @returns {Array<{key: string, blockName: string, displayName: string, isOutlet: boolean, outletName: string}>}
   */
  @cached
  get segments() {
    return this.wireframeSelection.selectedBlockAncestry;
  }

  /**
   * `true` when there is a currently-selected block (and therefore a
   * non-empty ancestry to display).
   *
   * @returns {boolean}
   */
  get hasSelection() {
    return this.segments.length > 0;
  }

  /**
   * Selects the block represented by the clicked breadcrumb segment.
   * Clicking the outlet segment clears the selection instead, since
   * the outlet itself is not a selectable block.
   *
   * @param {{key: string, blockName: string, isOutlet: boolean}} segment
   */
  @action
  pickSegment(segment) {
    if (segment.isOutlet) {
      this.wireframeSelection.selectBlock(null);
      return;
    }
    this.wireframeSelection.selectBlock({
      key: segment.key,
      name: segment.blockName,
    });
  }

  <template>
    {{#if this.hasSelection}}
      <nav
        class="wireframe-breadcrumb"
        aria-label={{i18n "wireframe.canvas.breadcrumb_label"}}
      >
        {{#each this.segments as |segment index|}}
          {{#if index}}
            <span class="wireframe-breadcrumb__separator" aria-hidden="true">
              {{dIcon "chevron-right"}}
            </span>
          {{/if}}
          <DButton
            class="wireframe-breadcrumb__segment"
            @translatedLabel={{segment.displayName}}
            @action={{fn this.pickSegment segment}}
          />
        {{/each}}
      </nav>
    {{/if}}
  </template>
}
