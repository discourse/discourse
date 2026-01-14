import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { service } from "@ember/service";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

class SolvedPostsStream {
  @tracked content = [];
  @tracked loading = false;
  @tracked loaded = false;
  @tracked itemsLoaded = 0;
  @tracked canLoadMore = true;

  constructor({ username, siteCategories }) {
    this.username = username;
    this.siteCategories = siteCategories;
  }

  get noContent() {
    return this.loaded && this.content.length === 0;
  }

  findItems() {
    if (this.loading || !this.canLoadMore) {
      return Promise.resolve();
    }

    this.loading = true;

    const limit = 20;
    return ajax(
      `/solution/by_user.json?username=${this.username}&offset=${this.itemsLoaded}&limit=${limit}`
    )
      .then((result) => {
        const userSolvedPosts = result.user_solved_posts || [];

        if (userSolvedPosts.length === 0) {
          this.canLoadMore = false;
          return;
        }

        const posts = userSolvedPosts.map((p) => {
          const post = EmberObject.create(p);
          post.set("titleHtml", post.topic_title);
          post.set("postUrl", post.url);

          if (post.category_id && this.siteCategories) {
            post.set(
              "category",
              this.siteCategories.find((c) => c.id === post.category_id)
            );
          }
          return post;
        });

        this.content = [...this.content, ...posts];
        this.itemsLoaded = this.itemsLoaded + userSolvedPosts.length;

        if (userSolvedPosts.length < limit) {
          this.canLoadMore = false;
        }
      })
      .finally(() => {
        this.loaded = true;
        this.loading = false;
      });
  }
}

export default class UserActivitySolved extends DiscourseRoute {
  @service site;
  @service currentUser;

  model() {
    const user = this.modelFor("user");

    const stream = new SolvedPostsStream({
      username: user.username,
      siteCategories: this.site.categories,
    });

    return stream.findItems().then(() => {
      return {
        stream,
        emptyState: this.emptyState(),
      };
    });
  }

  setupController(controller, model) {
    controller.setProperties({
      model,
      emptyState: this.emptyState(),
    });
  }

  renderTemplate() {
    this.render("user-activity-solved");
  }

  emptyState() {
    const user = this.modelFor("user");

    let title, body;
    if (this.currentUser && user.id === this.currentUser.id) {
      title = i18n("solved.no_solved_topics_title");
      body = i18n("solved.no_solved_topics_body");
    } else {
      title = i18n("solved.no_solved_topics_title_others", {
        username: user.username,
      });
      body = "";
    }

    return { title, body };
  }
}
