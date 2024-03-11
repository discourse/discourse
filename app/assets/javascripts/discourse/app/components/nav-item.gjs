/* You might be looking for navigation-item. */
import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import getURL from "discourse-common/lib/get-url";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "discourse-i18n";

export default class NavItem extends Component {
  @service router;

  get contents() {
    const text = this.args.i18nLabel || I18n.t(this.args.label);
    if (this.args.icon) {
      return htmlSafe(`${iconHTML(this.args.icon)} ${text}`);
    }
    return text;
  }

  get active() {
    if (!this.args.route) {
      return;
    }

    if (this.args.routeParam && this.router.currentRoute) {
      return this.router.currentRoute.params.filter === this.args.routeParam;
    }

    return this.router.isActive(this.args.route);
  }

  <template>
    <li class={{concatClass (if this.active "active") @class}} ...attributes>
      {{#if @routeParam}}
        <LinkTo
          @route={{@route}}
          @model={{@routeParam}}
        >{{this.contents}}</LinkTo>
      {{else if @route}}
        <LinkTo @route={{@route}}>{{this.contents}}</LinkTo>
      {{else}}
        <a href={{getURL @path}} data-auto-route="true">{{this.contents}}</a>
      {{/if}}
    </li>
  </template>
}
