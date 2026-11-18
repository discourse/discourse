/* You might be looking for navigation-item. */
import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import type RouterService from "@ember/routing/router-service";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isPresent } from "@ember/utils";
import getURL from "discourse/lib/get-url";
import { iconHTML } from "discourse/lib/icon-library";
import { applyValueTransformer } from "discourse/lib/transformer";
import type Session from "discourse/models/session";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

interface DNavItemSignature {
  Args: {
    /** The translation key of the label. */
    label?: string;

    /** The label, already translated. It takes precedence over `@label`. */
    i18nLabel?: string;

    /** The ID of an icon shown before the label. */
    icon?: string;

    /** The route the item links to. */
    route?: string;

    /** The model of `@route`. It also decides whether the item is active. */
    routeParam?: string;

    /**
     * Whether the item is active: a boolean, or a space-separated list of the route
     * names it is active for.
     */
    currentWhen?: boolean | string;

    /** The URL the item links to, when it has no `@route`. */
    path?: string;

    /** Classes added to the item. */
    class?: string;
  };

  Element: HTMLLIElement;
}

export default class DNavItem extends Component<DNavItemSignature> {
  @service declare router: RouterService;
  @service declare session: Session;

  get contents() {
    const text = this.args.i18nLabel || i18n(this.args.label);
    if (this.args.icon) {
      return trustHTML(`${iconHTML(this.args.icon)} ${text}`);
    }
    return text;
  }

  get active() {
    if (!this.args.route) {
      return;
    }

    const { currentRoute } = this.router;
    if (!currentRoute) {
      return;
    }

    if (isPresent(this.args.currentWhen)) {
      const currentWhen = this.args.currentWhen;
      if (typeof currentWhen === "boolean") {
        return currentWhen;
      } else if (typeof currentWhen === "string") {
        return currentWhen
          .split(" ")
          .some((route) => route === currentRoute.name);
      } else {
        return false;
      }
    }

    if (this.args.routeParam) {
      const params = currentRoute.params ?? {};

      if (currentRoute.name === "adminConfig.login.plugin-tab") {
        return params.wildcard === this.args.routeParam;
      }

      if (params.filter) {
        return params.filter === this.args.routeParam;
      }

      if (params.field_name) {
        return params.field_name === this.args.routeParam;
      }

      return this.router.isActive(this.args.route, this.args.routeParam);
    }

    return this.router.isActive(this.args.route);
  }

  get refreshHref() {
    if (!this.args.route) {
      return null;
    }
    try {
      const href = this.args.routeParam
        ? getURL(this.router.urlFor(this.args.route, this.args.routeParam))
        : getURL(this.router.urlFor(this.args.route));

      const shouldRefresh = applyValueTransformer(
        "full-page-refresh-on-navigation",
        this.session.requiresRefresh,
        { url: href }
      );
      return shouldRefresh ? href : null;
    } catch {
      return null;
    }
  }

  <template>
    <li class={{dConcatClass (if this.active "active") @class}} ...attributes>
      {{#if this.refreshHref}}
        <a href={{this.refreshHref}}>{{this.contents}}</a>
      {{else if @routeParam}}
        <LinkTo
          @current-when={{this.active}}
          @model={{@routeParam}}
          @route={{@route}}
        >{{this.contents}}</LinkTo>
      {{else if @route}}
        <LinkTo
          @current-when={{this.active}}
          @route={{@route}}
        >{{this.contents}}</LinkTo>
      {{else}}
        <a data-auto-route="true" href={{getURL @path}}>{{this.contents}}</a>
      {{/if}}
    </li>
  </template>
}
