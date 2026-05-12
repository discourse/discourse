// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
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
 * The path itself is derived in the visual-editor service via
 * `selectedBlockAncestry`, which walks the live layout from the
 * outlet root to the selected key and returns an array of
 * `{key, displayName, isOutlet, outletName}` segments.
 */
export default class BlockBreadcrumb extends Component {
  @service visualEditor;

  @cached
  get segments() {
    return this.visualEditor.selectedBlockAncestry;
  }

  get hasSelection() {
    return this.segments.length > 0;
  }

  @action
  pickSegment(segment) {
    if (segment.isOutlet) {
      this.visualEditor.selectBlock(null);
      return;
    }
    this.visualEditor.selectBlock({
      key: segment.key,
      name: segment.blockName,
    });
  }

  <template>
    {{#if this.hasSelection}}
      <nav
        class="visual-editor-breadcrumb"
        aria-label={{i18n "visual_editor.canvas.breadcrumb_label"}}
      >
        {{#each this.segments as |segment index|}}
          {{#if index}}
            <span
              class="visual-editor-breadcrumb__separator"
              aria-hidden="true"
            >
              {{dIcon "chevron-right"}}
            </span>
          {{/if}}
          <button
            type="button"
            class="visual-editor-breadcrumb__segment"
            {{on "click" (fn this.pickSegment segment)}}
          >
            {{segment.displayName}}
          </button>
        {{/each}}
      </nav>
    {{/if}}
  </template>
}
