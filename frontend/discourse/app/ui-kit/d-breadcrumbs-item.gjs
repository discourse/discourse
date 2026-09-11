import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import getURL from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class DBreadcrumbsItem extends Component {
  @service breadcrumbs;

  constructor() {
    super(...arguments);
    this.breadcrumbs.items.add(this);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.breadcrumbs.items.delete(this);
  }

  // @cached
  get templateForContainer() {
    // Those are evaluated in a different context than the `@linkClass`
    const { label, path, route } = this.args;

    return <template>
      <li ...attributes>
        {{#if route}}
          <LinkTo class={{@linkClass}} @route={{route}}>
            {{label}}
          </LinkTo>
        {{else}}
          <a class={{@linkClass}} href={{getURL path}}>
            {{label}}
          </a>
        {{/if}}
        {{#unless @isLast}}
          <span class="separator">
            {{~dIcon "angle-right"~}}
          </span>
        {{/unless}}
      </li>
    </template>;
  }
}
