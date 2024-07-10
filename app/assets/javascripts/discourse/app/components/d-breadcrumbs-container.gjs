import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { eq } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";

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
    <ul {{this.registerContainer}} class="d-breadcrumbs" ...attributes>
      {{#each this.breadcrumbs.items as |item index|}}
        {{#let item.templateForContainer as |Template|}}
          <Template
            @linkClass={{concatClass
              "d-breadcrumbs__link"
              @additionalLinkClasses
            }}
            aria-current={{if (eq index this.lastItemIndex) "page"}}
            class={{concatClass "d-breadcrumbs__item" @additionalItemClasses}}
          />
        {{/let}}
      {{/each}}
    </ul>
  </template>
}
