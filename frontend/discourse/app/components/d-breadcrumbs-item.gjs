import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";

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
          <LinkTo @route={{route}} class={{@linkClass}}>
            {{label}}
          </LinkTo>
        {{else}}
          <a href={{getURL path}} class={{@linkClass}}>
            {{label}}
          </a>
        {{/if}}
        <span class="separator">
          {{~icon "angle-right"~}}
        </span>
      </li>
    </template>;
  }
}
