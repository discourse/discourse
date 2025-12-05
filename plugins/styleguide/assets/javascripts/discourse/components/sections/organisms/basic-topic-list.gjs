import Component from "@glimmer/component";
import BasicTopicList from "discourse/components/basic-topic-list";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class BasicTopicListOrganism extends Component {
  get basicTopicListCode() {
    return `
import BasicTopicList from "discourse/components/basic-topic-list";

<template>
  <BasicTopicList @topics={{@dummy.topics}} />
</template>
    `;
  }

  <template>
    <StyleguideExample
      @title="<BasicTopicList>"
      class="half-size"
      @code={{this.basicTopicListCode}}
    >
      <BasicTopicList @topics={{@dummy.topics}} />
    </StyleguideExample>
  </template>
}
