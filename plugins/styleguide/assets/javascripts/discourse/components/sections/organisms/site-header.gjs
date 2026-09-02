import Component from "@glimmer/component";
import { inject as controller } from "@ember/controller";
import SiteHeaderExample from "../../examples/organisms/site-header";
import siteHeaderSource from "../../examples/organisms/site-header?source=file";
import SiteHeaderInTopicExample from "../../examples/organisms/site-header-in-topic";
import siteHeaderInTopicSource from "../../examples/organisms/site-header-in-topic?source=file";
import StyleguideExample from "../../styleguide-example";

export default class SiteHeaderStyleguideExample extends Component {
  @controller application;

  get sidebarEnabled() {
    return this.application.sidebarEnabled;
  }

  <template>
    <StyleguideExample @code={{siteHeaderSource}} @title="site header">
      <SiteHeaderExample @sidebarEnabled={{this.sidebarEnabled}} />
    </StyleguideExample>

    <StyleguideExample
      @code={{siteHeaderInTopicSource}}
      @title="site header - in topic - scrolled"
    >
      <SiteHeaderInTopicExample
        @sidebarEnabled={{this.sidebarEnabled}}
        @topic={{@dummy.topic}}
      />
    </StyleguideExample>
  </template>
}
