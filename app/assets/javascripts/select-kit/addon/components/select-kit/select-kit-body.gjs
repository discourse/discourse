import Component from "@ember/component";
import { computed } from "@ember/object";
import { next } from "@ember/runloop";
import { classNameBindings, classNames } from "@ember-decorators/component";
import { bind } from "discourse/lib/decorators";

@classNames("select-kit-body")
@classNameBindings("emptyBody:empty-body")
export default class SelectKitBody extends Component {
  @computed("selectKit.{filter,hasNoContent}")
  get emptyBody() {
    return false;
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    this.element.style.position = "relative";
    document.addEventListener("click", this.handleClick, true);
    this.selectKit
      .mainElement()
      .addEventListener("keydown", this._handleKeydown, true);
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    document.removeEventListener("click", this.handleClick, true);
    this.selectKit
      .mainElement()
      ?.removeEventListener("keydown", this._handleKeydown, true);
  }

  @bind
  handleClick(event) {
    if (!this.selectKit.isExpanded || !this.selectKit.mainElement()) {
      return;
    }

    if (this.selectKit.mainElement().contains(event.target)) {
      return;
    }

    this.selectKit.close(event);
  }

  @bind
  _handleKeydown(event) {
    if (!this.selectKit.isExpanded || event.key !== "Tab") {
      return;
    }

    next(() => {
      if (
        this.isDestroying ||
        this.isDestroyed ||
        this.selectKit.mainElement()?.contains(document.activeElement)
      ) {
        return;
      }

      this.selectKit.close(event);
    });
  }
}
