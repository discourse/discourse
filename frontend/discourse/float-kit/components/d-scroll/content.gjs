import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";

/**
 * DScroll.Content - The scrollable content wrapper.
 *
 * This component represents the content that moves as scroll occurs.
 *
 * @component
 * @param {Object} @controller - The scroll controller instance
 */
export default class DScrollContent extends Component {
  /**
   * Build data-d-scroll attribute value for content element.
   *
   * @returns {string}
   */
  get dataAttribute() {
    const parts = ["content"];
    const controller = this.args.controller;

    if (controller?.overflowX) {
      parts.push("overflow-x");
    } else {
      parts.push("no-overflow-x");
    }
    if (controller?.overflowY) {
      parts.push("overflow-y");
    } else {
      parts.push("no-overflow-y");
    }
    if (controller?.trapX) {
      parts.push("trap-x");
    }
    if (controller?.trapY) {
      parts.push("trap-y");
    }

    return parts.join(" ");
  }

  <template>
    <div
      data-d-scroll={{this.dataAttribute}}
      {{didInsert @controller.registerContent}}
      ...attributes
    >
      {{yield}}
    </div>
  </template>
}
