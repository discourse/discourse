import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import SidebarToggle from "./sidebar-toggle";
import MountWidget from "../mount-widget";
import PluginOutlet from "../plugin-outlet";

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
      {{#if this.site.desktopView}}
        {{#if @sidebarEnabled}}
          <SidebarToggle @toggleHamburger={{@toggleHamburger}} />
        {{/if}}
      {{/if}}

      <div class="home-logo-wrapper-outlet">
        <PluginOutlet @name="home-logo-wrapper">
          {{! I don't think data is working here }}
          <MountWidget @widget="home-logo" @args={{@data}} />
        </PluginOutlet>
      </div>

      {{!-- {{#if attrs.topic}}
        {{header-topic-info attrs=@args}}
      {{else if this.siteSettings.bootstrap_mode_enabled}}
        {{#if transformed.showBootstrapMode}}
          {{header-bootstrap-mode attrs=@args}}
        {{/if}}
      {{/if}} --}}

      {{!-- <PluginOutlet
        @name="before-header-panel"
        @outletArgs={{hash topic=@args.topic}}
      /> --}}
      {{!-- {{before-header-panel-outlet attrs=@args}} --}}

      <div class="panel" role="navigation">{{yield}}</div>
    </div>
  </template>
}
