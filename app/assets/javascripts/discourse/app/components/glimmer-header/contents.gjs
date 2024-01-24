import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import SidebarToggle from "./sidebar-toggle";
import MountWidget from "../mount-widget";
import PluginOutlet from "../plugin-outlet";
import BootstrapModeNotice from "../bootstrap-mode-notice";
import and from "truth-helpers/helpers/and";
import TopicInfo from "./topic/info";
import { hash } from "@ember/helper";
import not from "truth-helpers/helpers/not";

export default class Contents extends Component {
  @service site;
  @service currentUser;
  @service siteSettings;

  get topicPresent() {
    return !!this.args.topic;
  }

  <template>
    <div class="contents">
      {{#if this.site.desktopView}}
        {{#if @sidebarEnabled}}
          <SidebarToggle @toggleHamburger={{@toggleHamburger}} />
        {{/if}}
      {{/if}}

      <div class="home-logo-wrapper-outlet">
        <PluginOutlet @name="home-logo-wrapper">
          <MountWidget
            @widget="home-logo"
            @args={{hash minimized=this.topicPresent}}
          />
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

      <div class="before-header-panel-outlet">
        <PluginOutlet
          @name="before-header-panel"
          @outletArgs={{hash topic=@topic}}
        />
      </div>
      <div class="panel" role="navigation">{{yield}}</div>
    </div>
  </template>
}
