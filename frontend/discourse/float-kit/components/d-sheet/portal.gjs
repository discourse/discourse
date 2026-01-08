import Component from "@glimmer/component";

/**
 * Portal component that renders content into document.body when sheet is presented.
 *
 * @component Portal
 * @param {Object} sheet - The sheet controller instance
 * @param {boolean} shouldRenderView - Whether the view should be rendered (from Root)
 */
export default class Portal extends Component {
  get element() {
    return this.args.container ?? document.body;
  }

  /**
   * Whether to render the portal content.
   * Uses shouldRenderView from Root if provided (controlled mode),
   * otherwise falls back to sheet.isPresented (uncontrolled mode).
   *
   * @type {boolean}
   */
  get shouldRender() {
    if (this.args.shouldRenderView !== undefined) {
      return this.args.shouldRenderView;
    }
    return this.args.sheet?.isPresented ?? false;
  }

  <template>
    {{#in-element this.element insertBefore=null}}
      {{#if this.shouldRender}}
        {{yield}}
      {{/if}}
    {{/in-element}}
  </template>
}
