import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { hash } from "@ember/helper";
import Content from "./content";
import ScrollController from "./controller";
import Trigger from "./trigger";
import View from "./view";

/**
 * DScroll.Root - Root component that wraps all scroll sub-components.
 *
 * Creates a scroll controller instance and provides it to child components
 * via the yielded hash. The controller exposes the imperative API.
 *
 * @component
 * @yields {Object} scroll - The scroll context object
 * @yields {Component} scroll.View - The View sub-component
 * @yields {Component} scroll.Content - The Content sub-component
 * @yields {Function} scroll.getProgress - Get scroll progress (0-1)
 * @yields {Function} scroll.getDistance - Get scroll distance in pixels
 * @yields {Function} scroll.getAvailableDistance - Get total scrollable distance
 * @yields {Function} scroll.scrollTo - Scroll to position
 * @yields {Function} scroll.scrollBy - Scroll by delta
 */
export default class DScrollRoot extends Component {
  controller = new ScrollController();

  constructor() {
    super(...arguments);

    registerDestructor(this, () => {
      this.controller.cleanup();
    });
  }

  <template>
    {{yield
      (hash
        Trigger=(component Trigger controller=this.controller)
        View=(component View controller=this.controller)
        Content=(component Content controller=this.controller)
        getProgress=this.controller.getProgress
        getDistance=this.controller.getDistance
        getAvailableDistance=this.controller.getAvailableDistance
        scrollTo=this.controller.scrollTo
        scrollBy=this.controller.scrollBy
      )
    }}
  </template>
}
