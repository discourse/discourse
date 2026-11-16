import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import getURL from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class DBreadcrumbsItem extends Component {
  @service breadcrumbs;
  @service router;

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
    const { label, route } = this.args;
    // An item with no target stands for the current page. An empty href would
    // reload the page, and on a subfolder install it would point at the root.
    const path = this.args.path ?? this.router.currentURL;

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
