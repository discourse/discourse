import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dElement from "discourse/ui-kit/helpers/d-element";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import devToolsState from "../state";

/**
 * Block debug button with dropdown menu.
 * Provides separate toggles for outlet boundaries, visual overlay, ghost blocks,
 * and condition debugging.
 */
export default class BlockDebugButton extends Component {
  /**
   * Determines if any block debug feature is currently enabled.
   * Used to highlight the toolbar button when debugging is active.
   *
   * @returns True if any block debug mode is enabled.
   */
  get isActive(): boolean {
    return (
      devToolsState.blockDebug ||
      devToolsState.blockVisualOverlay ||
      devToolsState.blockGhostBlocks ||
      devToolsState.blockOutletBoundaries
    );
  }

  /**
   * Toggles outlet boundary indicators around block outlets.
   * When enabled, shows visual borders around each block outlet area.
   *
   * @param event - The checkbox change event.
   */
  @action
  toggleOutletBoundaries(event: Event): void {
    devToolsState.blockOutletBoundaries = (
      event.target as HTMLInputElement
    ).checked;
  }

  /**
   * Toggles visual overlay that displays block information on the page.
   * When enabled, shows badges and tooltips on rendered blocks.
   *
   * @param event - The checkbox change event.
   */
  @action
  toggleVisualOverlay(event: Event): void {
    devToolsState.blockVisualOverlay = (
      event.target as HTMLInputElement
    ).checked;
  }

  /**
   * Toggles ghost blocks that show hidden blocks with dashed outlines.
   * When enabled, shows placeholder outlines for blocks that weren't rendered
   * (e.g., failed conditions, optional missing, no visible children).
   *
   * @param event - The checkbox change event.
   */
  @action
  toggleGhostBlocks(event: Event): void {
    devToolsState.blockGhostBlocks = (event.target as HTMLInputElement).checked;
  }

  /**
   * Toggles condition debugging for block condition evaluation.
   * When enabled, logs detailed information about each block's condition checks.
   *
   * @param event - The checkbox change event.
   */
  @action
  toggleConditionDebugging(event: Event): void {
    devToolsState.blockDebug = (event.target as HTMLInputElement).checked;
  }

  <template>
    <DMenu
      @identifier="block-debug-menu"
      @modalForMobile={{false}}
      @title={{i18n "dev_tools.toggle_block_debug"}}
      @triggerClass={{dConcatClass
        "toggle-blocks"
        (if this.isActive "--active")
      }}
      @triggerComponent={{dElement "button"}}
    >
      <:trigger>
        {{dIcon "cubes"}}
      </:trigger>
      <:content>
        <div class="block-debug-menu">
          <label>
            <input
              checked={{devToolsState.blockOutletBoundaries}}
              type="checkbox"
              {{on "change" this.toggleOutletBoundaries}}
            />
            {{i18n "dev_tools.block_debug.outlet_boundaries"}}
          </label>
          <label>
            <input
              checked={{devToolsState.blockVisualOverlay}}
              type="checkbox"
              {{on "change" this.toggleVisualOverlay}}
            />
            {{i18n "dev_tools.block_debug.visual_overlay"}}
          </label>
          <label>
            <input
              checked={{devToolsState.blockGhostBlocks}}
              type="checkbox"
              {{on "change" this.toggleGhostBlocks}}
            />
            {{i18n "dev_tools.block_debug.ghost_blocks"}}
          </label>
          <label>
            <input
              checked={{devToolsState.blockDebug}}
              type="checkbox"
              {{on "change" this.toggleConditionDebugging}}
            />
            {{i18n "dev_tools.block_debug.condition_debugging"}}
          </label>
        </div>
      </:content>
    </DMenu>
  </template>
}
