import Component from "@glimmer/component";
import TopicList from "discourse/components/topic-list/list";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class TopicListOrganism extends Component {
  get topicListCode() {
    return `
import TopicList from "discourse/components/topic-list/list";

<template>
  <TopicList @topics={{@dummy.topics}} @showPosters={{true}} />
</template>
    `;
  }

  get topicListHidePostersCode() {
    return `
import TopicList from "discourse/components/topic-list/list";

<template>
  <TopicList @topics={{@dummy.topics}} @showPosters={{false}} />
</template>
    `;
  }

  <template>
    <StyleguideExample @title="<TopicList>" @code={{this.topicListCode}}>
      <TopicList @topics={{@dummy.topics}} @showPosters={{true}} />
    </StyleguideExample>

    <StyleguideExample
      @title="<TopicList> - hide posters>"
      @code={{this.topicListHidePostersCode}}
    >
      <TopicList @topics={{@dummy.topics}} @showPosters={{false}} />
    </StyleguideExample>
  </template>
}
