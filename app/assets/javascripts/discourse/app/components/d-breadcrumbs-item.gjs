import Component from "@glimmer/component";
import { service } from "@ember/service";

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

  get url() {
    try {
      if (this.args.model) {
        return this.router.urlFor(this.args.route, this.args.model);
      } else {
        return this.router.urlFor(this.args.route);
      }
    } catch {
      // if the route can't be resolved, ignore
    }
  }

  get templateForContainer() {
    // Those are evaluated in a different context than the `@linkClass`
    const { label } = this.args;
    const url = this.url;

    return <template>
      {{#if url}}
        <li ...attributes>
          <a href={{url}} class={{@linkClass}}>
            {{label}}
          </a>
        </li>
      {{/if}}
    </template>;
  }
}
