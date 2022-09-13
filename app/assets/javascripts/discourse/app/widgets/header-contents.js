import { createWidget } from "discourse/widgets/widget";
import hbs from "discourse/widgets/hbs-compiler";

createWidget("header-contents", {
  tagName: "div.contents",
  template: hbs`
    <div class="header-logo-wrapper">
      {{#if this.site.desktopView}}
        {{#if this.siteSettings.enable_experimental_sidebar_hamburger}}
          {{#if attrs.sidebarEnabled}}
            {{sidebar-toggle attrs=attrs}}
          {{/if}}
        {{/if}}
      {{/if}}
      {{home-logo attrs=attrs}}
    </div>
    {{#if attrs.topic}}
      {{header-topic-info attrs=attrs}}
    {{/if}}
    <div class="panel clearfix" role="navigation">{{yield}}</div>
  `,
});
