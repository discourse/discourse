import Component from "@glimmer/component";
import { action } from "@ember/object";
import { later } from "@ember/runloop";

const NO_TRANSITION = "no-transition";

export default class UserMenuTab extends Component {
  get isActive() {
    return this.args.tab.id === this.args.currentTabId;
  }

  get classNames() {
    const list = ["btn", "btn-flat", "btn-icon", "no-text", "user-menu-tab"];
    if (this.isActive) {
      list.push("active");
      if (this.renderAsLink) {
        list.push(NO_TRANSITION);
      }
    }
    return list.join(" ");
  }

  get id() {
    return `user-menu-button-${this.args.tab.id}`;
  }

  get tabIndex() {
    return this.isActive ? "0" : "-1";
  }

  get ariaControls() {
    return `quick-access-${this.args.tab.id}`;
  }

  get renderAsLink() {
    return this.isActive && this.args.tab.linkWhenActive;
  }

  @action
  focusLink(link) {
    // tabs are initially rendered as <button> elements, and when a tab is
    // activated, the <button> element is replaced with an <a>. However, this
    // element replacement operation causes the focus to be lost and go back to
    // <body> so we need to manually move the focus back the new <a> element.
    link.focus();
    later(this, this.#removeNoTransitionClass, link, 10);
  }

  #removeNoTransitionClass(link) {
    link.classList.remove(NO_TRANSITION);
  }
}
