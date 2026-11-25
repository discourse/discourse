/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { action, computed, set } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { classNameBindings } from "@ember-decorators/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

@classNameBindings("docked")
export default class TopicProgress extends Component {
  @service mobileTabBar;

  elementId = "topic-progress-wrapper";
  docked = false;

  /** @type {number | null} */
  progressPosition = null;

  #dockFrame = null;
  #postsObserver = null;

  // Docked once the posts end above the navigation, which the tab bar holds
  // in place over the page
  #checkDocked = () => {
    cancelAnimationFrame(this.#dockFrame);
    this.#dockFrame = requestAnimationFrame(() => {
      const navigation = this.element?.parentElement;
      const posts = navigation?.parentElement;

      if (!posts) {
        return;
      }

      const docked =
        posts.getBoundingClientRect().bottom <
        navigation.getBoundingClientRect().bottom - 1;

      if (docked !== this.docked) {
        this.set("docked", docked);
      }
    });
  };

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

    // The tab bar hides the progress at the end of the topic
    if (this.mobileTabBar.enabled) {
      window.addEventListener("scroll", this.#checkDocked, { passive: true });

      // More posts loading moves the end of the topic without a scroll
      this.#postsObserver = new ResizeObserver(this.#checkDocked);
      this.#postsObserver.observe(this.element.parentElement.parentElement);
      this.#checkDocked();
    }
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    window.removeEventListener("scroll", this.#checkDocked);
    this.#postsObserver?.disconnect();
    cancelAnimationFrame(this.#dockFrame);
    this.appEvents.off(
      "topic:current-post-scrolled",
      this,
      this._topicScrolled
    );
  }

  click(e) {
    if (e.target.closest("#topic-progress")) {
      this.onExpandToggle?.();
    }
  }

  @action
  goBack() {
    this.jumpToPost(this.get("topic.last_read_post_number"));
  }

  _topicScrolled(event) {
    if (this.docked && !this.mobileTabBar.enabled) {
      this.setProperties({
        progressPosition: this.get("postStream.filteredPostsCount"),
        _streamPercentage: 100,
      });
      return;
    }

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
          class="btn-primary btn-small progress-back"
          @action={{this.goBack}}
          @icon="arrow-down"
          @label="topic.timeline.back"
        />
      </div>
    {{/if}}

    <nav
      aria-label={{i18n "topic.progress.title"}}
      class={{if this.hideProgress "hidden"}}
      id="topic-progress"
      style={{trustHTML this.progressStyle}}
      title={{i18n "topic.progress.title"}}
    >
      <div class="nums">
        <span>{{this.progressPosition}}</span>
        <span>/</span>
        <span>{{this.postStream.filteredPostsCount}}</span>
      </div>
      <div class="bg"></div>
    </nav>

    <PluginOutlet @connectorTagName="div" @name="after-topic-progress" />
  </template>
}
