import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import bodyClass from "discourse/helpers/body-class";
import { bind } from "discourse/lib/decorators";

/**
 * Centres a topic in the space beside the channel list (see `.concord-topic`
 * in the stylesheet), and tells the composer where the topic starts, since
 * the composer is fixed to the window and can't line itself up.
 */
export default class TopicLayout extends Component {
  #observer;

  @bind
  observe() {
    const outlet = document.getElementById("main-outlet");
    if (!outlet) {
      return;
    }

    // The outlet keeps its full width and centres the topic with padding, so
    // anything that moves the topic also resizes the outlet.
    this.#observer = new ResizeObserver(() => {
      const left =
        outlet.getBoundingClientRect().left +
        parseFloat(getComputedStyle(outlet).paddingLeft);
      document.documentElement.style.setProperty(
        "--concord-topic-left",
        `${left}px`
      );
    });
    this.#observer.observe(outlet);
  }

  @bind
  disconnect() {
    this.#observer?.disconnect();
    document.documentElement.style.removeProperty("--concord-topic-left");
  }

  <template>
    {{bodyClass "concord-topic"}}
    <div
      hidden
      {{didInsert this.observe}}
      {{willDestroy this.disconnect}}
    ></div>
  </template>
}
