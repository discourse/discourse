import Component from "@glimmer/component";
import { inject as controller } from "@ember/controller";
import Header from "discourse/components/header";
import StyleguideExample from "../../styleguide-example";

export default class SiteHeaderStyleguideExample extends Component {
  @controller application;

  get sidebarEnabled() {
    return this.application.sidebarEnabled;
  }

  <template>
    <StyleguideExample @title="site header">
      <div inert class="d-header-wrap">
        <Header @sidebarEnabled={{this.sidebarEnabled}} />
      </div>
    </StyleguideExample>
    <StyleguideExample @title="site header - in topic - scrolled">
      <div inert class="d-header-wrap">
        <Header
          @sidebarEnabled={{this.sidebarEnabled}}
          @topicInfo={{@dummy.topic}}
          @topicInfoVisible={{true}}
        />
      </div>
    </StyleguideExample>
  </template>
}
