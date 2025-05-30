import Component from "@glimmer/component";
import { modifier as modifierFn } from "ember-modifier";
import { or } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";

export default class FKSection extends Component {
  sizeSection = modifierFn((element, [floating]) => {
    if (!floating) {
      return;
    }

    const resizer = () => {
      const container = document.getElementById("main-container");

      if (!container) {
        return;
      }

      const { width } = container.getBoundingClientRect();
      element.style.width = `${width}px`;
    };

    resizer();

    window.addEventListener("resize", resizer);

    return () => {
      window.removeEventListener("resize", resizer);
    };
  });

  <template>
    <div
      {{this.sizeSection @floating}}
      class={{concatClass "form-kit__section" @class}}
      ...attributes
    >
      {{#if (or @title @subtitle)}}
        <div class="form-kit__section-header">
          {{#if @title}}
            <h3 class="form-kit__section-title">{{@title}}</h3>
          {{/if}}

          {{#if @subtitle}}
            <span class="form-kit__section-subtitle">{{@subtitle}}</span>
          {{/if}}
        </div>
      {{/if}}

      {{yield}}
    </div>
  </template>
}
