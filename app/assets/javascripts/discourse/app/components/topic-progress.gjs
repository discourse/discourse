/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import { scheduleOnce } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { classNameBindings } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

@classNameBindings("docked")
export default class TopicProgress extends Component {
  elementId = "topic-progress-wrapper";
  docked = false;
  progressPosition = null;

  @alias("topic.postStream") postStream;

  _streamPercentage = null;

  @discourseComputed(
    "postStream.loaded",
    "topic.currentPost",
    "postStream.filteredPostsCount"
  )
  hideProgress(loaded, currentPost, filteredPostsCount) {
    const hideOnShortStream = this.site.desktopView && filteredPostsCount < 2;
    return !loaded || !currentPost || hideOnShortStream;
  }

  @discourseComputed("postStream.filteredPostsCount")
  hugeNumberOfPosts(filteredPostsCount) {
    return (
      filteredPostsCount >= this.siteSettings.short_progress_text_threshold
    );
  }

  @discourseComputed("progressPosition", "topic.last_read_post_id")
  showBackButton(position, lastReadId) {
    if (!lastReadId) {
      return;
    }

    const stream = this.get("postStream.stream");
    const readPos = stream.indexOf(lastReadId) || 0;

    return readPos < stream.length - 1 && readPos > position;
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

  @discourseComputed("_streamPercentage")
  progressStyle(_streamPercentage) {
    return `--progress-bg-width: ${_streamPercentage || 0}%`;
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
