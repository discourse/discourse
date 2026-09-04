import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier as modifierFn } from "ember-modifier";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class DSegmentedControl extends Component {
  positionSlider = modifierFn((element, [value]) => {
    if (!value) {
      return;
    }

    const checked = element.querySelector("input:checked");
    if (!checked) {
      return;
    }

    const slider = element.querySelector(".d-segmented-control__slider");
    const label = checked.closest(".d-segmented-control__label");
    const frameId = requestAnimationFrame(() => {
      element.style.setProperty("--slider-x", `${label.offsetLeft}px`);
      element.style.setProperty("--slider-width", `${label.offsetWidth}px`);

      if (!slider.classList.contains("is-animated")) {
        requestAnimationFrame(() => slider.classList.add("is-animated"));
      }
    });

    return () => cancelAnimationFrame(frameId);
  });

  get classNames() {
    const classes = ["d-segmented-control"];
    if (this.args.size === "small") {
      classes.push("d-segmented-control--small");
    }
    return classes.join(" ");
  }

  get legend() {
    if (this.args.label) {
      return i18n(this.args.label);
    }
    return this.args.translatedLabel;
  }

  @action
  handleChange(value) {
    this.args.onSelect?.(value);
  }

  @action
  handleClick(value) {
    this.args.onClickItem?.(value);
  }

  <template>
    <fieldset
      class={{this.classNames}}
      {{this.positionSlider @value}}
      ...attributes
    >
      {{#if this.legend}}
        <legend class="d-segmented-control__legend">
          {{this.legend}}
        </legend>
      {{/if}}

      <span class="d-segmented-control__slider"></span>

      {{#each @items as |item|}}
        <label
          class={{dConcatClass
            "d-segmented-control__label"
            item.class
            (if item.disabled "is-disabled")
          }}
          title={{item.title}}
          {{on "click" (fn this.handleClick item.value)}}
        >
          <input
            type="radio"
            name={{@name}}
            value={{item.value}}
            checked={{eq @value item.value}}
            disabled={{item.disabled}}
            class="d-segmented-control__input"
            aria-label={{item.title}}
            {{on "change" (fn this.handleChange item.value)}}
          />
          {{! The title doubles as the hover tooltip (on the label) and the
            accessible name (on the input), so an icon-only segment — one with
            an icon and no visible label — is still announced and discoverable. }}
          <span class="d-segmented-control__text">
            {{#if item.icon}}{{dIcon item.icon}}{{/if}}
            {{item.label}}
          </span>
        </label>
      {{/each}}
    </fieldset>
  </template>
}
