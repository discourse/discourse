import Component from "@ember/component";
import { computed } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { guidFor } from "@ember/object/internals";

export default class OnVisibilityAction extends Component {
  action = null;

  root = document.body;

  @computed
  get onVisibilityActionId() {
    return "on-visibility-action-" + guidFor(this);
  }

  _element() {
    return document.getElementById(this.onVisibilityActionId);
  }

  didInsertElement() {
    this._super(...arguments);

    let options = {
      root: this.root,
      rootMargin: "0px",
      threshold: 1.0,
    };

    this._observer = new IntersectionObserver(this._handleIntersect, options);
    this._observer.observe(this._element());
  }

  willDestroyElement() {
    this._super(...arguments);

    this._observer?.disconnect();
    this.root = null;
  }

  @bind
  _handleIntersect(entries) {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        this.action?.();
      }
    });
  }
}
