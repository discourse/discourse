// @ts-check
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
/** @type {import("discourse/float-kit/components/d-menu.gjs").default} */
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
/** @type {import("discourse/helpers/element.gjs").default} */
import element from "discourse/helpers/element";
import { i18n } from "discourse-i18n";
import devToolsState from "../state";

/**
 * Block debug button with dropdown menu.
 * Provides separate toggles for console logging, visual overlay, and outlet boundaries.
 *
 * @component BlockDebugButton
 */
export default class BlockDebugButton extends Component {
  /**
   * Determines if any block debug feature is currently enabled.
   * Used to highlight the toolbar button when debugging is active.
   *
   * @returns {boolean} True if any block debug mode is enabled.
   */
  get isActive() {
    return (
      devToolsState.blockDebug ||
      devToolsState.blockVisualOverlay ||
      devToolsState.blockOutletBoundaries
    );
  }

  /**
   * Toggles console logging for block condition evaluation.
   * When enabled, logs detailed information about each block's condition checks.
   *
   * @param {Event} event - The checkbox change event.
   */
  @action
  toggleConsoleLogging(event) {
    devToolsState.blockDebug = /** @type {HTMLInputElement} */ (
      event.target
    ).checked;
  }

  /**
   * Toggles visual overlay that displays block information on the page.
   * When enabled, shows badges and tooltips on rendered blocks.
   *
   * @param {Event} event - The checkbox change event.
   */
  @action
  toggleVisualOverlay(event) {
    devToolsState.blockVisualOverlay = /** @type {HTMLInputElement} */ (
      event.target
    ).checked;
  }

  /**
   * Toggles outlet boundary indicators around block outlets.
   * When enabled, shows visual borders around each block outlet area.
   *
   * @param {Event} event - The checkbox change event.
   */
  @action
  toggleOutletBoundaries(event) {
    devToolsState.blockOutletBoundaries = /** @type {HTMLInputElement} */ (
      event.target
    ).checked;
  }

  <template>
    <DMenu
      @identifier="block-debug-menu"
      @triggerClass={{concatClass
        "toggle-blocks"
        (if this.isActive "--active")
      }}
      @triggerComponent={{element "button"}}
      @modalForMobile={{false}}
      @title={{i18n "dev_tools.toggle_block_debug"}}
    >
      <:trigger>
        {{icon "cubes"}}
      </:trigger>
      <:content>
        <div class="block-debug-menu">
          <label>
            <input
              type="checkbox"
              checked={{devToolsState.blockDebug}}
              {{on "change" this.toggleConsoleLogging}}
            />
            {{i18n "dev_tools.block_debug.console_logging"}}
          </label>
          <label>
            <input
              type="checkbox"
              checked={{devToolsState.blockVisualOverlay}}
              {{on "change" this.toggleVisualOverlay}}
            />
            {{i18n "dev_tools.block_debug.visual_overlay"}}
          </label>
          <label>
            <input
              type="checkbox"
              checked={{devToolsState.blockOutletBoundaries}}
              {{on "change" this.toggleOutletBoundaries}}
            />
            {{i18n "dev_tools.block_debug.outlet_boundaries"}}
          </label>
        </div>
      </:content>
    </DMenu>
  </template>
}
