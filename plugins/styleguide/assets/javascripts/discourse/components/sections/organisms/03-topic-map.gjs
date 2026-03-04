import Component from "@glimmer/component";
import TopicMap from "discourse/components/topic-map";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class TopicMapOrganism extends Component {
  get topicMapCode() {
    return `
import TopicMap from "discourse/components/topic-map";

<template>
  <TopicMap
    @model={{@dummy.postModel}}
    @topicDetails={{@dummy.postModel.topic.details}}
  />
</template>
    `;
  }

  <template>
    <StyleguideExample @title="topic-map" @code={{this.topicMapCode}}>
      <TopicMap
        @model={{@dummy.postModel}}
        @topicDetails={{@dummy.postModel.topic.details}}
      />
    </StyleguideExample>
  </template>
}
