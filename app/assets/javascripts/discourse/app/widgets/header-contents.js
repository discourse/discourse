import { createWidget } from "discourse/widgets/widget";
import hbs from "discourse/widgets/hbs-compiler";

createWidget("header-contents", {
  tagName: "div.contents.clearfix",
  transform() {
    return {
      staff: this.get("currentUser.staff"),
    };
  },
  template: hbs`
    {{#if this.site.desktopView}}
      {{#if attrs.sidebarEnabled}}
        {{sidebar-toggle attrs=attrs}}
      {{/if}}
    {{/if}}

    {{home-logo attrs=attrs}}

    {{#if attrs.topic}}
      {{header-topic-info attrs=attrs}}
    {{else if this.siteSettings.bootstrap_mode_enabled}}
      {{#if transformed.staff}}
        {{header-bootstrap-mode attrs=attrs}}
      {{/if}}
    {{/if}}

    <div class="panel clearfix" role="navigation">{{yield}}</div>
  `,
});
