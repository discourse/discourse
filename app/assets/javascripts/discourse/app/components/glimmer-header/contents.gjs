import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import SidebarToggle from "./sidebar-toggle";
import MountWidget from "../mount-widget";
import PluginOutlet from "../plugin-outlet";
import BootstrapModeNotice from "../bootstrap-mode-notice";
import and from "truth-helpers/helpers/and";
import TopicInfo from "./topic/info";

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
          {{!-- <MountWidget @widget="home-logo" @attrs={{@args}} /> --}}
        </PluginOutlet>
      </div>

      {{#if @topic}}
        <TopicInfo @topic={{@topic}} />
      {{else if
        (and
          this.siteSettings.bootstrap_mode_enabled
          this.currentUser.staff
          this.site.desktopView
        )
      }}
        <div class="d-header-mode">
          <BootstrapModeNotice />
        </div>
      {{/if}}

      {{!-- <PluginOutlet
        @name="before-header-panel"
        @outletArgs={{hash topic=@args.topic}}
      /> --}}
      {{!-- {{before-header-panel-outlet attrs=@args}} --}}

      <div class="panel" role="navigation">{{yield}}</div>
    </div>
  </template>
}
