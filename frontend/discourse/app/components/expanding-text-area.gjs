import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import autoFocus from "discourse/modifiers/auto-focus";

export default class ExpandingTextArea extends Component {
  setTextarea = modifier((element) => {
    this.#textarea = element;

    const placeholderObserver = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (
          mutation.type === "attributes" &&
          mutation.attributeName === "placeholder"
        ) {
          this.autoResize();
        }
      });
    });

    placeholderObserver.observe(element, {
      attributes: true,
      attributeFilter: ["placeholder"],
    });

    const handleResize = () => this.autoResize();
    window.addEventListener("resize", handleResize);

    this.autoResize();

    return () => {
      placeholderObserver.disconnect();
      window.removeEventListener("resize", handleResize);
      this.#textarea = null;
    };
  });

  #textarea;

  @action
  autoResize() {
    setTimeout(() => {
      if (!this.#textarea) {
        return;
      }

      this.#textarea.style.height = "auto";
      this.#textarea.style.height = this.#textarea.scrollHeight + "px";

      // Get the max-height value from CSS (30vh)
      const maxHeight = parseInt(
        getComputedStyle(this.#textarea).maxHeight,
        10
      );

      // Only enable scrolling if content exceeds max-height
      if (this.#textarea.scrollHeight > maxHeight) {
        this.#textarea.style.overflowY = "auto";
      } else {
        this.#textarea.style.overflowY = "hidden";
      }
    }, 50);
  }

  <template>
    <textarea
      {{this.setTextarea}}
      {{(if @autoFocus autoFocus)}}
      {{! deprecated args: }}
      autocorrect={{@autocorrect}}
      class={{@class}}
      maxlength={{@maxlength}}
      name={{@name}}
      rows={{@rows}}
      value={{@value}}
      {{(if @input (modifier on "input" @input))}}
      {{on "input" this.autoResize}}
      {{on "focus" this.autoResize}}
      {{on "blur" this.autoResize}}
      ...attributes
    ></textarea>
  </template>
}
