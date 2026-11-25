/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { action, computed, set } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import { trustHTML } from "@ember/template";
import {
  attributeBindings,
  classNameBindings,
} from "@ember-decorators/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

@attributeBindings("ariaLabel:aria-label")
@classNameBindings("docked")
export default class TopicProgress extends Component {
  elementId = "topic-progress-wrapper";
  docked = false;

  /** @type {number | null} */
  progressPosition = null;

  /** @type {number | string | null} */
  _streamPercentage = null;

  @computed("topic.postStream")
  get postStream() {
    return this.topic?.postStream;
  }

  set postStream(value) {
    set(this, "topic.postStream", value);
  }

  @computed(
    "postStream.loaded",
    "topic.currentPost",
    "postStream.filteredPostsCount"
  )
  get hideProgress() {
    const hideOnShortStream =
      this.site.desktopView && this.postStream?.filteredPostsCount < 2;
    return (
      !this.postStream?.loaded || !this.topic?.currentPost || hideOnShortStream
    );
  }

  @computed(
    "progressPosition",
    "topic.last_read_post_id",
    "topic.last_read_post_number",
    "postStream.filteredPostsCount"
  )
  get showBackButton() {
    if (!this.topic?.last_read_post_id) {
      return;
    }

    const readPos = this.postStream.progressIndexOfPostId({
      id: this.topic.last_read_post_id,
      post_number: this.topic.last_read_post_number,
    });

    return (
      readPos < this.postStream.filteredPostsCount &&
      readPos > this.progressPosition + 1
    );
  }

  @computed("hideProgress", "showBackButton")
  get ariaRole() {
    return !this.hideProgress || this.showBackButton ? "navigation" : null;
  }

  @computed("ariaRole")
  get ariaLabel() {
    return this.ariaRole ? i18n("topic.progress.title") : null;
  }

  @computed("_streamPercentage")
  get progressStyle() {
    return `--progress-bg-width: ${this._streamPercentage || 0}%`;
  }

  @computed("progressPosition", "postStream.filteredPostsCount")
  get progressLabel() {
    const total = this.postStream?.filteredPostsCount;
    if (!this.progressPosition || !total) {
      return i18n("topic.progress.title");
    }

    return i18n("topic.progress.position", {
      current: this.progressPosition,
      total,
    });
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    this.appEvents.on("topic:current-post-scrolled", this, this._topicScrolled);

    if (this.prevEvent) {
      scheduleOnce("afterRender", this, this._topicScrolled, this.prevEvent);
    }
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this.appEvents.off(
      "topic:current-post-scrolled",
      this,
      this._topicScrolled
    );
  }

  @action
  goBack() {
    this.jumpToPost(this.get("topic.last_read_post_number"));
  }

  _topicScrolled(event) {
    this.setProperties({
      progressPosition: event.postIndex,
      _streamPercentage: (event.percent * 100).toFixed(2),
    });
  }

  <template>
    {{#unless this.hideProgress}}
      {{yield}}
    {{/unless}}

    {{#if this.showBackButton}}
      <div class="progress-back-container">
        <DButton
          class={{dConcatClass
            "btn-small progress-back"
            (if this.footerSlot "btn-default" "btn-primary")
          }}
          @action={{this.goBack}}
          @icon="arrow-down"
          @label={{unless this.footerSlot "topic.timeline.back"}}
          @title="topic.timeline.back_description"
        />
      </div>
    {{/if}}

    <DButton
      class="btn-transparent {{if this.hideProgress 'hidden'}}"
      id="topic-progress"
      style={{trustHTML this.progressStyle}}
      @action={{this.onExpandToggle}}
      @title="topic.progress.title"
      @translatedAriaLabel={{this.progressLabel}}
    >
      <span class="nums">
        <span>{{this.progressPosition}}</span>
        <span>/</span>
        <span>{{this.postStream.filteredPostsCount}}</span>
      </span>
      <span class="bg"></span>
    </DButton>

    <PluginOutlet @connectorTagName="div" @name="after-topic-progress" />
  </template>
}
