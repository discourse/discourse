import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import type RouterService from "@ember/routing/router-service";
import { service } from "@ember/service";
import { makeArray } from "discourse/lib/helpers";

interface DNavigationItemSignature {
  Args: {
    /** The route the item links to. */
    route: string;

    /** The models of `@route`. */
    models?: unknown[];

    /** The model of `@route`, used when there is no `@models`. */
    model?: unknown;

    /**
     * Which level of a nested navigation the item belongs to. A `parentNav` item is
     * the current page while one of its child routes is current, and a `subNav` item
     * of the current route is the current location.
     */
    ariaCurrentContext?: "parentNav" | "subNav";

    /** Classes added to the item. */
    class?: string;

    /** The title of the item, shown on hover. */
    title?: string;
  };

  Element: HTMLLIElement;

  Blocks: {
    /** The link text. */
    default: [];
  };
}

export default class DNavigationItem extends Component<DNavigationItemSignature> {
  @service declare router: RouterService;

  get ariaCurrent() {
    // when there are multiple levels of navigation
    // we want the active parent to get `aria-current="page"`
    // and the active child to get `aria-current="location"`
    if (
      this.args.ariaCurrentContext === "parentNav" &&
      this.router.currentRouteName !== this.args.route && // not the current route
      this.router.currentRoute?.parent?.name.includes(this.args.route) // but is the current parent route
    ) {
      return "page";
    }

    if (this.router.currentRouteName !== this.args.route) {
      return null;
    }

    if (this.args.ariaCurrentContext === "subNav") {
      return "location";
    } else {
      return "page";
    }
  }

  get models() {
    return makeArray(this.args.models || this.args.model);
  }

  <template>
    <li
      aria-current={{this.ariaCurrent}}
      class={{@class}}
      title={{@title}}
      ...attributes
    >
      {{#if this.models}}
        <LinkTo @models={{this.models}} @route={{@route}}>
          {{yield}}
        </LinkTo>
      {{else}}
        <LinkTo @route={{@route}}>
          {{yield}}
        </LinkTo>
      {{/if}}
    </li>
  </template>
}
