import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { bind } from "discourse/lib/decorators";

const DO_NOT_RENDER_LIST = ["login"];

export default class ExperimentalScreen extends Component {
  @service router;

  @tracked left = 0;
  @tracked right = 0;
  resizeObserver;

  willDestroy() {
    super.willDestroy(...arguments);
    this.resizeObserver.disconnect();
  }

  @bind
  calculateDistance(element) {
    const distance = element.getBoundingClientRect();
    this.left = distance.left;
    this.right = distance.right;
  }

  get distanceStyles() {
    return htmlSafe(
      `--left-distance: ${this.left}px; --right-distance: ${this.right}px;`
    );
  }

  get shouldRender() {
    return !DO_NOT_RENDER_LIST.includes(this.router.currentRouteName);
  }

  @action
  onInsert(element) {
    this.calculateDistance(element);

    this.resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        this.calculateDistance(entry.target);
      }
    });

    this.resizeObserver.observe(element);
  }

  <template>
    {{#if this.shouldRender}}
      <ul
        class="experimental-screen"
        {{didInsert this.onInsert}}
        style={{this.distanceStyles}}
      >
        <li class="experimental-screen__top-left"></li>
        <li class="experimental-screen__top-right"></li>
        <li class="experimental-screen__bottom-left"></li>
        <li class="experimental-screen__bottom-right"></li>
        <li class="experimental-screen__bottom-bar"></li>
      </ul>
    {{/if}}
  </template>
}
