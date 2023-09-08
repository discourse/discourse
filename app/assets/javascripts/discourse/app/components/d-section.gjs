import Component from "@glimmer/component";
import { scheduleOnce } from "@ember/runloop";
import notEq from "truth-helpers/helpers/not-eq";

// Can add a body class from within a component
export default class DSection extends Component {
  <template>
    {{#if (notEq @tagName "")}}
      <section id={{@id}} class={{@class}} ...attributes>{{yield}}</section>
    {{else}}
      {{yield}}
    {{/if}}
  </template>

  currentClasses = new Set();

  constructor() {
    super(...arguments);
    scheduleOnce("afterRender", this, this._updateClasses);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    scheduleOnce("afterRender", this, this._removeClasses);
  }

  _updateClasses() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    const desiredClasses = new Set();
    if (this.args.pageClass) {
      desiredClasses.add(`${this.args.pageClass}-page`);
    }
    if (this.args.bodyClass) {
      for (const bodyClass of this.args.bodyClass.split(" ")) {
        desiredClasses.add(bodyClass);
      }
    }

    document.body.classList.add(...desiredClasses);
    const removeClasses = [...this.currentClasses].filter(
      (c) => !desiredClasses.has(c)
    );
    document.body.classList.remove(...removeClasses);
    this.currentClasses = desiredClasses;
  }

  _removeClasses() {
    document.body.classList.remove(...this.currentClasses);
  }
}
