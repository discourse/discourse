/* You might be looking for navigation-item. */
import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isPresent } from "@ember/utils";
import concatClass from "discourse/helpers/concat-class";
import getURL from "discourse/lib/get-url";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";

export default class NavItem extends Component {
  @service router;

  get contents() {
    const text = this.args.i18nLabel || i18n(this.args.label);
    if (this.args.icon) {
      return htmlSafe(`${iconHTML(this.args.icon)} ${text}`);
    }
    return text;
  }

  get active() {
    if (!this.args.route || !this.router.currentRoute) {
      return;
    }

    if (isPresent(this.args.currentWhen)) {
      const currentWhen = this.args.currentWhen;
      if (typeof currentWhen === "boolean") {
        return currentWhen;
      } else if (typeof currentWhen === "string") {
        return currentWhen
          .split(" ")
          .some((route) => route === this.router.currentRoute.name);
      } else {
        return false;
      }
    }

    if (this.args.routeParam) {
      // This is needed because the setting route is underneath /admin/plugins/:plugin_id,
      // but is not a child route of the plugin routes themselves. E.g. discourse-ai
      // for the plugin ID has its own nested routes defined in the plugin.
      if (this.router.currentRoute.name === "adminPlugins.show.settings") {
        return (
          this.router.currentRoute.parent.params.plugin_id ===
          this.args.routeParam
        );
      }

      if (this.router.currentRoute.params.filter) {
        return this.router.currentRoute.params.filter === this.args.routeParam;
      }

      if (this.router.currentRoute.params.field_name) {
        return (
          this.router.currentRoute.params.field_name === this.args.routeParam
        );
      }
    }

    return this.router.isActive(this.args.route);
  }

  <template>
    <li class={{concatClass (if this.active "active") @class}} ...attributes>
      {{#if @routeParam}}
        <LinkTo
          @route={{@route}}
          @model={{@routeParam}}
          @current-when={{this.active}}
        >{{this.contents}}</LinkTo>
      {{else if @route}}
        <LinkTo
          @route={{@route}}
          @current-when={{this.active}}
        >{{this.contents}}</LinkTo>
      {{else}}
        <a href={{getURL @path}} data-auto-route="true">{{this.contents}}</a>
      {{/if}}
    </li>
  </template>
}
