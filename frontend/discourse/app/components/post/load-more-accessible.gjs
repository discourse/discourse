import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import LoadMore from "discourse/components/load-more";
import { i18n } from "discourse-i18n";

export default class PostLoadMoreAccessible extends Component {
  @service a11yAnnouncer;

  @tracked isLoading = false;

  get canLoadMore() {
    return this.args.canLoadMore ?? true;
  }

  get direction() {
    return this.args.direction || "below";
  }

  get enabled() {
    return this.args.enabled ?? true;
  }

  get label() {
    if (this.args.loadingText) {
      return this.args.loadingText;
    }

    return i18n(
      this.direction === "above"
        ? "post.load_more_posts_above"
        : "post.load_more_posts_below"
    );
  }

  @action
  async handleLoadAndAnnouncement() {
    if (!this.enabled || !this.canLoadMore || this.isLoading) {
      return;
    }

    try {
      this.isLoading = true;
      await this.args.action();
      this.a11yAnnouncer.announce(i18n("post.loading_complete"), "polite");
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <LoadMore
      @action={{this.handleLoadAndAnnouncement}}
      @enabled={{this.enabled}}
    />

    {{! Screen reader accessible heading for navigation-based loading }}
    <div class="post-stream-load-more-accessible sr-only">
      <h2
        class="post-stream-load-more-accessible__heading"
        id="post-stream-load-more-heading__{{this.direction}}"
      >
        {{if this.isLoading (i18n "post.loading_more_posts") this.label}}
      </h2>
    </div>
  </template>
}
