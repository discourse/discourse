import Component from "@glimmer/component";

export default class Portal extends Component {
  get element() {
    return (
      this.args.container ??
      document.getElementById("ember-testing") ??
      document.body
    );
  }

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
