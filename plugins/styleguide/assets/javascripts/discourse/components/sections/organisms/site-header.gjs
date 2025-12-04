import Component from "@glimmer/component";
import { inject as controller } from "@ember/controller";
import Header from "discourse/components/header";
import StyleguideExample from "../../styleguide-example";

export default class SiteHeaderStyleguideExample extends Component {
  @controller application;

  get sidebarEnabled() {
    return this.application.sidebarEnabled;
  }

  get headerCode() {
    return `import Header from "discourse/components/header";

<template>
  <div inert class="d-header-wrap">
    <Header @sidebarEnabled={{this.sidebarEnabled}} />
  </div>
</template>`;
  }

  get headerInTopicCode() {
    return `import Header from "discourse/components/header";

<template>
  <div inert class="d-header-wrap">
    <Header
      @sidebarEnabled={{this.sidebarEnabled}}
      @topicInfo={{@dummy.topic}}
      @topicInfoVisible={{true}}
    />
  </div>
</template>`;
  }

  <template>
    <StyleguideExample @title="site header" @code={{this.headerCode}}>
      <div inert class="d-header-wrap">
        <Header @sidebarEnabled={{this.sidebarEnabled}} />
      </div>
    </StyleguideExample>
    <StyleguideExample
      @title="site header - in topic - scrolled"
      @code={{this.headerInTopicCode}}
    >
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
