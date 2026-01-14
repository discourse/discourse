import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import Container from "discourse/components/topic-timeline/container";
import concatClass from "discourse/helpers/concat-class";

export default class TopicTimeline extends Component {
  @tracked docked = false;
  @tracked dockedBottom = false;
  enteredIndex = this.args.prevEvent
    ? this.args.prevEvent.postIndex - 1
    : this.args.enteredIndex;

  addShowClass = modifier((el) => {
    if (this.args.fullscreen) {
      el.classList.add("show");
    }
  });

  @action
  setDocked(value) {
    if (this.docked !== value) {
      this.docked = value;
    }
  }

  @action
  setDockedBottom(value) {
    if (this.dockedBottom !== value) {
      this.dockedBottom = value;
    }
  }

  <template>
    <div
      {{this.addShowClass}}
      class={{concatClass
        "timeline-container"
        (if @fullscreen "timeline-fullscreen")
        (if this.docked "timeline-docked")
        (if this.dockedBottom "timeline-docked-bottom")
      }}
    >
      <div class="topic-timeline">
        <Container
          @model={{@model}}
          @enteredIndex={{this.enteredIndex}}
          @jumpTop={{@jumpTop}}
          @jumpBottom={{@jumpBottom}}
          @jumpEnd={{@jumpEnd}}
          @jumpToIndex={{@jumpToIndex}}
          @jumpToPostPrompt={{@jumpToPostPrompt}}
          @fullscreen={{@fullscreen}}
          @toggleMultiSelect={{@toggleMultiSelect}}
          @showTopicSlowModeUpdate={{@showTopicSlowModeUpdate}}
          @showTopReplies={{@showTopReplies}}
          @deleteTopic={{@deleteTopic}}
          @recoverTopic={{@recoverTopic}}
          @toggleClosed={{@toggleClosed}}
          @toggleArchived={{@toggleArchived}}
          @toggleVisibility={{@toggleVisibility}}
          @showTopicTimerModal={{@showTopicTimerModal}}
          @showFeatureTopic={{@showFeatureTopic}}
          @showChangeTimestamp={{@showChangeTimestamp}}
          @resetBumpDate={{@resetBumpDate}}
          @convertToPublicTopic={{@convertToPublicTopic}}
          @convertToPrivateMessage={{@convertToPrivateMessage}}
          @replyToPost={{@replyToPost}}
          @setDocked={{this.setDocked}}
          @setDockedBottom={{this.setDockedBottom}}
        />
      </div>
    </div>
  </template>
}
