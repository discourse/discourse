import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { prefixProtocol } from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import PostEventRecording from "../modal/post-event-recording";
import OneboxEmbed from "./onebox-embed";

export default class DiscoursePostEventRecording extends Component {
  @service currentUser;
  @service modal;

  get recordingUrl() {
    return prefixProtocol(this.args.event.recordingUrl);
  }

  get canAddRecording() {
    const { event } = this.args;

    return (
      !!this.currentUser &&
      event.canActOnDiscoursePostEvent &&
      event.livestream &&
      event.isExpired
    );
  }

  @action
  addRecording() {
    this.modal.show(PostEventRecording, { model: { event: this.args.event } });
  }

  <template>
    {{#if @event.recordingOnebox}}
      <section class="event__section event-recording">
        <OneboxEmbed @html={{@event.recordingOnebox}} @post={{@post}} />
      </section>
    {{else if @event.recordingUrl}}
      <section class="event__section event-recording">
        <DButton
          class="btn-primary event-recording__watch"
          rel="noopener noreferrer"
          target="_blank"
          @href={{this.recordingUrl}}
          @icon="play"
          @label="discourse_post_event.recording.watch"
        />
      </section>
    {{else if this.canAddRecording}}
      <section class="event__section event-recording">
        <DButton
          class="btn-default event-recording__add"
          @action={{this.addRecording}}
          @icon="plus"
          @label="discourse_post_event.recording.add"
        />
      </section>
    {{/if}}
  </template>
}
