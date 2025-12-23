/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { alias } from "@ember/object/computed";
import { scheduleOnce } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { classNameBindings } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import { i18n } from "discourse-i18n";

@classNameBindings("docked")
export default class TopicProgress extends Component {
  elementId = "topic-progress-wrapper";
  docked = false;
  progressPosition = null;

  @alias("topic.postStream") postStream;

  _streamPercentage = null;

  @computed(
    "postStream.loaded",
    "topic.currentPost",
    "postStream.filteredPostsCount"
  )
  get hideProgress() {
    const hideOnShortStream = this.site.desktopView && this.postStream?.filteredPostsCount < 2;
    return !this.postStream?.loaded || !this.topic?.currentPost || hideOnShortStream;
  }

  @computed("postStream.filteredPostsCount")
  get hugeNumberOfPosts() {
    return (
      this.postStream?.filteredPostsCount >= this.siteSettings.short_progress_text_threshold
    );
  }

  @computed("progressPosition", "topic.last_read_post_id")
  get showBackButton() {
    if (!this.topic?.last_read_post_id) {
      return;
    }

    const stream = this.get("postStream.stream");
    const readPos = stream.indexOf(this.topic?.last_read_post_id) || 0;

    return readPos < stream.length - 1 && readPos > this.progressPosition;
  }

  _topicScrolled(event) {
    if (this.docked) {
      this.setProperties({
        progressPosition: this.get("postStream.filteredPostsCount"),
        _streamPercentage: 100,
      });
    } else {
      this.setProperties({
        progressPosition: event.postIndex,
        _streamPercentage: (event.percent * 100).toFixed(2),
      });
    }
  }

  @computed("_streamPercentage")
  get progressStyle() {
    return `--progress-bg-width: ${this._streamPercentage || 0}%`;
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

  click(e) {
    if (e.target.closest("#topic-progress")) {
      this.toggleProperty("expanded");
    }
  }

  @action
  goBack() {
    this.jumpToPost(this.get("topic.last_read_post_number"));
  }

  <template>
    {{#unless this.hideProgress}}
      {{yield}}
    {{/unless}}

    {{#if this.showBackButton}}
      <div class="progress-back-container">
        <DButton
          @label="topic.timeline.back"
          @action={{this.goBack}}
          @icon="arrow-down"
          class="btn-primary btn-small progress-back"
        />
      </div>
    {{/if}}

    <nav
      title={{i18n "topic.progress.title"}}
      aria-label={{i18n "topic.progress.title"}}
      class={{if this.hideProgress "hidden"}}
      id="topic-progress"
      style={{htmlSafe this.progressStyle}}
    >
      <div class="nums">
        <span>{{this.progressPosition}}</span>
        <span class={{if this.hugeNumberOfPosts "hidden"}}>/</span>
        <span
          class={{if this.hugeNumberOfPosts "hidden"}}
        >{{this.postStream.filteredPostsCount}}</span>
      </div>
      <div class="bg"></div>
    </nav>

    <PluginOutlet @name="after-topic-progress" @connectorTagName="div" />
  </template>
}
