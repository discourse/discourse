import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class Contents extends Component {
  @service site;
  @service currentUser;
  @service siteSettings;

  // transform() {
  //   return {
  //     showBootstrapMode: this.currentUser?.staff && this.site.desktopView,
  //   };
  // }

  <template>
    <div class="contents">
      {{!-- {{#if this.site.desktopView}}
        {{#if attrs.sidebarEnabled}}
          {{sidebar-toggle attrs=@args}}
        {{/if}}
      {{/if}}

      {{home-logo-wrapper-outlet attrs=@args}}

      {{#if attrs.topic}}
        {{header-topic-info attrs=@args}}
      {{else if this.siteSettings.bootstrap_mode_enabled}}
        {{#if transformed.showBootstrapMode}}
          {{header-bootstrap-mode attrs=@args}}
        {{/if}}
      {{/if}}

      <PluginOutlet
        @name="before-header-panel"
        @outletArgs={{hash topic=@args.topic}}
      />
      {{before-header-panel-outlet attrs=@args}} --}}

      <div class="panel" role="navigation">{{yield}}</div>
    </div>
  </template>
}
