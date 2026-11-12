import Component from "@glimmer/component";
import { modifier as modifierFn } from "ember-modifier";
import { or } from "discourse/truth-helpers/index";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class FKSection extends Component {
  sizeSection = modifierFn((element, [floating]) => {
    if (!floating) {
      return;
    }

    const resizer = () => {
      const container = document.getElementsByClassName(
        this.args.floatContainerClass
      )[0];

      if (!container) {
        return;
      }

      const { width } = container.getBoundingClientRect();
      element.style.width = `calc(${width}px - var(--space-3)*2)`;
    };

    resizer();

    window.addEventListener("resize", resizer);

    return () => {
      window.removeEventListener("resize", resizer);
    };
  });

  <template>
    <div
      class={{dConcatClass "form-kit__section" @class}}
      ...attributes
      {{this.sizeSection @floating}}
    >
      {{#if (or @title @subtitle (has-block "header"))}}
        <div class="form-kit__section-header">
          {{#if (or @title @subtitle)}}
            <div class="form-kit__section-heading">
              {{#if @title}}
                <h3 class="form-kit__section-title">{{@title}}</h3>
              {{/if}}

              {{#if @subtitle}}
                <span class="form-kit__section-subtitle">{{@subtitle}}</span>
              {{/if}}
            </div>
          {{/if}}

          {{yield to="header"}}
        </div>
      {{/if}}

      {{yield}}
    </div>
  </template>
}
