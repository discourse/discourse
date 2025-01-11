import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse-common/lib/get-url";

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
    const { label, path } = this.args;

    return <template>
      <li ...attributes>
        <a href={{getURL path}} class={{@linkClass}}>
          {{label}}
        </a>
        <span class="separator">
          {{~icon "angle-right"~}}
        </span>
      </li>
    </template>;
  }
}
