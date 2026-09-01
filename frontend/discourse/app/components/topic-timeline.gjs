import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import Container from "discourse/components/topic-timeline/container";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

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
      class={{dConcatClass
        "timeline-container"
        (if @fullscreen "timeline-fullscreen")
        (if this.docked "timeline-docked")
        (if this.dockedBottom "timeline-docked-bottom")
      }}
      {{this.addShowClass}}
    >
      <div class="topic-timeline">
        <Container
          @convertToPrivateMessage={{@convertToPrivateMessage}}
          @convertToPublicTopic={{@convertToPublicTopic}}
          @deleteTopic={{@deleteTopic}}
          @enteredIndex={{this.enteredIndex}}
          @fullscreen={{@fullscreen}}
          @jumpBottom={{@jumpBottom}}
          @jumpEnd={{@jumpEnd}}
          @jumpToIndex={{@jumpToIndex}}
          @jumpTop={{@jumpTop}}
          @jumpToPostPrompt={{@jumpToPostPrompt}}
          @model={{@model}}
          @recoverTopic={{@recoverTopic}}
          @replyToPost={{@replyToPost}}
          @resetBumpDate={{@resetBumpDate}}
          @setDocked={{this.setDocked}}
          @setDockedBottom={{this.setDockedBottom}}
          @showChangeTimestamp={{@showChangeTimestamp}}
          @showFeatureTopic={{@showFeatureTopic}}
          @showTopicSlowModeUpdate={{@showTopicSlowModeUpdate}}
          @showTopicTimerModal={{@showTopicTimerModal}}
          @showTopReplies={{@showTopReplies}}
          @toggleArchived={{@toggleArchived}}
          @toggleClosed={{@toggleClosed}}
          @toggleMultiSelect={{@toggleMultiSelect}}
          @toggleVisibility={{@toggleVisibility}}
        />
      </div>
    </div>
  </template>
}
