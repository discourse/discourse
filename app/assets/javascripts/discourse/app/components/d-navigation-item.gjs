import Component from "@glimmer/component";
import { service } from "@ember/service";
import { makeArray } from "discourse/lib/helpers";
import { LinkTo } from "@ember/routing";

export default class DNavigationItem extends Component {<template><li aria-current={{this.ariaCurrent}} title={{@title}} class={{@class}} ...attributes>
  {{#if this.models}}
    <LinkTo @route={{@route}} @models={{this.models}}>
      {{yield}}
    </LinkTo>
  {{else}}
    <LinkTo @route={{@route}}>
      {{yield}}
    </LinkTo>
  {{/if}}
</li></template>
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
}
