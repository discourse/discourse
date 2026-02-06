import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import ScrollController from "./controller";

/**
 * DScroll.Root - Root component that wraps all scroll sub-components.
 *
 * Creates a scroll controller instance and provides it to child components
 * via the yielded hash. The controller exposes the imperative API.
 *
 * @component
 * @yields {Object} controller - the scroll controller
 */
export default class DScrollRoot extends Component {
  controller = new ScrollController();

  constructor() {
    super(...arguments);

    registerDestructor(this, () => {
      this.controller.cleanup();
    });
  }

  <template>{{yield this.controller}}</template>
}
