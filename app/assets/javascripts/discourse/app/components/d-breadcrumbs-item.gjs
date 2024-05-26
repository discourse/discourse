import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class DBreadcrumbsItem extends Component {
  @service breadcrumbsService;

  <template>
    {{#each this.breadcrumbsService.containers as |container|}}
      {{#in-element container.element insertBefore=null}}
        <li class={{container.itemClass}} ...attributes>
          {{yield container.linkClass}}
        </li>
      {{/in-element}}
    {{/each}}
  </template>
}
