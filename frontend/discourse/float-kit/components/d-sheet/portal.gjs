import Component from "@glimmer/component";

/**
 * Portal component that renders content into document.body when sheet is presented.
 *
 * @component Portal
 * @param {import("./controller").default} sheet - The sheet controller instance
 * @param {HTMLElement} [container] - Optional custom container element to render into instead of document.body
 * @param {boolean} [shouldRenderView] - Whether the view should be rendered (from Root, controlled mode)
 */
export default class Portal extends Component {
  /**
   * Resolves the target DOM element for the in-element portal.
   * Prefers the provided container arg, falls back to the Ember testing container, then document.body.
   *
   * @type {HTMLElement}
   */
  get element() {
    return (
      this.args.container ??
      document.getElementById("ember-testing") ??
      document.body
    );
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
