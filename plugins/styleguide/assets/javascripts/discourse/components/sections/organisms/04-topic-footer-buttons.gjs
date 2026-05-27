import Component from "@glimmer/component";
import TopicFooterButtons from "discourse/components/topic-footer-buttons";
import DButton from "discourse/ui-kit/d-button";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class TopicFooterButtonsOrganism extends Component {
  get loggedInCode() {
    return `
import TopicFooterButtons from "discourse/components/topic-footer-buttons";

<template>
  <TopicFooterButtons @topic={{@dummy.topic}} />
</template>
    `;
  }

  get anonymousCode() {
    return `
import DButton from "discourse/components/d-button";

<template>
  <div id="topic-footer-buttons">
    <DButton
      @icon="reply"
      @label="topic.reply.title"
      class="btn-primary pull-right"
    />
  </div>
</template>
    `;
  }

  <template>
    <StyleguideExample
      @title="<TopicFooterButtons> - logged in"
      @code={{this.loggedInCode}}
    >
      <TopicFooterButtons @topic={{@dummy.topic}} />
    </StyleguideExample>

    <StyleguideExample
      @title="<TopicFooterButtons> - anonymous"
      @code={{this.anonymousCode}}
    >
      <div class="styleguide-anon">
        <div id="topic-footer-buttons">
          <DButton
            @icon="reply"
            @label="topic.reply.title"
            class="btn-primary pull-right"
          />
        </div>
      </div>
    </StyleguideExample>
  </template>
}
