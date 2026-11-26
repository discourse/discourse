import Component from "@glimmer/component";
import type { TOC } from "@ember/component/template-only";
import type Owner from "@ember/owner";
import { LinkTo } from "@ember/routing";
import type RouterService from "@ember/routing/router-service";
import { service } from "@ember/service";
import getURL from "discourse/lib/get-url";
import type { DeferredTrackedSet } from "discourse/lib/tracked-tools";
import dIcon from "discourse/ui-kit/helpers/d-icon";

/**
 * TODO(typescript-pending): the breadcrumbs service is untyped; drop this view once it
 * declares the types of its sets.
 */
export interface BreadcrumbsService {
  containers: DeferredTrackedSet<{ element: HTMLElement }>;
  items: DeferredTrackedSet<DBreadcrumbsItem>;
}

/** The template a breadcrumbs container renders for each item. */
export interface DBreadcrumbsItemTemplateSignature {
  Args: {
    /** Whether the item is the last one, which has no separator. */
    isLast: boolean;

    /** The classes of the item's link. */
    linkClass?: string;
  };

  Element: HTMLLIElement;
}

interface DBreadcrumbsItemSignature {
  Args: {
    /** The text of the item. */
    label: string;

    /**
     * The URL the item links to, when it has no `@route`. Without either, the
     * item links to the current page.
     */
    path?: string;

    /** The route the item links to. */
    route?: string;
  };
}

export default class DBreadcrumbsItem extends Component<DBreadcrumbsItemSignature> {
  @service declare breadcrumbs: BreadcrumbsService;
  @service declare router: RouterService;

  constructor(owner: Owner, args: DBreadcrumbsItemSignature["Args"]) {
    super(owner, args);
    this.breadcrumbs.items.add(this);
  }

  willDestroy() {
    super.willDestroy();
    this.breadcrumbs.items.delete(this);
  }

  // @cached
  get templateForContainer(): TOC<DBreadcrumbsItemTemplateSignature> {
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
