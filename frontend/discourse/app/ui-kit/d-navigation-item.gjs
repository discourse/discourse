import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { makeArray } from "discourse/lib/helpers";

export default class DNavigationItem extends Component {
  @service router;

  get ariaCurrent() {
    // when there are multiple levels of navigation
    // we want the active parent to get `aria-current="page"`
    // and the active child to get `aria-current="location"`
    if (
      this.args.ariaCurrentContext === "parentNav" &&
      this.router.currentRouteName !== this.args.route && // not the current route
      this.router.currentRoute.parent.name.includes(this.args.route) // but is the current parent route
    ) {
      return "page";
    }

    if (!this.isCurrent) {
      return null;
    }

    if (this.args.ariaCurrentContext === "subNav") {
      return "location";
    } else {
      return "page";
    }
  }

  // A string `@current-when` on `<LinkTo>` ignores `@models`, so resolve the extra routes here.
  get currentWhen() {
    if (!this.args.currentWhen) {
      return undefined;
    }

    return [this.args.route, ...this.args.currentWhen.split(" ")].some(
      (route) => this.router.isActive(route, ...this.models)
    );
  }

  get isCurrent() {
    return this.currentWhen ?? this.router.currentRouteName === this.args.route;
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
        <LinkTo
          @current-when={{this.currentWhen}}
          @models={{this.models}}
          @route={{@route}}
        >
          {{yield}}
        </LinkTo>
      {{else}}
        <LinkTo @current-when={{this.currentWhen}} @route={{@route}}>
          {{yield}}
        </LinkTo>
      {{/if}}
    </li>
  </template>
}
