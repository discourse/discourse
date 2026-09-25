import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";

const TRIGGERS =
  "[data-user-card], [data-group-card], a.mention, a.mention-group, a.hashtag-cooked, .hashtag";

// The cards load on the first click that would open one, then that click is replayed.
export default class LazyCardContainer extends Component {
  @tracked module;

  #loading;

  constructor() {
    super(...arguments);
    document.addEventListener("click", this.onClick, true);
    registerDestructor(this, () =>
      document.removeEventListener("click", this.onClick, true)
    );
  }

  @action
  onClick(event) {
    if (this.module || this.#loading) {
      return;
    }

    const trigger = event.target.closest?.(TRIGGERS);

    if (!trigger) {
      return;
    }

    event.preventDefault();
    event.stopImmediatePropagation();

    this.#loading = import("discourse/components/card-container").then(
      (module) => {
        this.module = module;
        requestAnimationFrame(() =>
          requestAnimationFrame(() => trigger.click())
        );
      }
    );
  }

  <template>
    {{#if this.module}}
      <this.module.default />
    {{/if}}
  </template>
}
