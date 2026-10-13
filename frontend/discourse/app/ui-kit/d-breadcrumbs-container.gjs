import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class DBreadcrumbsContainer extends Component {
  @service breadcrumbs;

  registerContainer = modifier((element) => {
    const container = { element };

    this.breadcrumbs.containers.add(container);
    return () => this.breadcrumbs.containers.delete(container);
  });

  get lastItemIndex() {
    return this.breadcrumbs.items.size - 1;
  }

  <template>
    <ul class="d-breadcrumbs" ...attributes {{this.registerContainer}}>
      {{#each this.breadcrumbs.items as |item index|}}
        {{#let item.templateForContainer as |Template|}}
          <Template
            aria-current={{if (eq index this.lastItemIndex) "page"}}
            class={{dConcatClass "d-breadcrumbs__item" @additionalItemClasses}}
            @isLast={{eq index this.lastItemIndex}}
            @linkClass={{dConcatClass
              "d-breadcrumbs__link"
              @additionalLinkClasses
            }}
          />
        {{/let}}
      {{/each}}
    </ul>
  </template>
}
