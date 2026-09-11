import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { modifier } from "ember-modifier";
import PostMenu from "discourse/components/post/menu";
import { popupAjaxError } from "discourse/lib/ajax-error";
import EmbedMode from "discourse/lib/embed-mode";

// Embed mode hides the first post because the embedding page already shows
// that content. This surfaces just its like and reaction controls so readers
// can react to the article itself without leaving the page.
export default class EmbedTopicActions extends Component {
  @tracked firstPost;

  loadFirstPost = modifier((element, [topic]) => {
    let cancelled = false;

    topic
      ?.firstPost()
      .then((post) => {
        if (!cancelled) {
          this.firstPost = post;
        }
      })
      .catch(() => {
        // Without the first post there is nothing to react to; the bar stays hidden.
      });

    return () => {
      cancelled = true;
    };
  });

  get isEmbedMode() {
    return EmbedMode.enabled;
  }

  @action
  async toggleLike() {
    const post = this.firstPost;
    const likeAction = post.likeAction;

    if (!likeAction?.canToggle) {
      return;
    }

    try {
      await likeAction.togglePromise(post);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  showLogin() {
    getOwner(this).lookup("route:application").send("showLogin");
  }

  <template>
    {{#if this.isEmbedMode}}
      <div class="embed-topic-actions" {{this.loadFirstPost @topic}}>
        {{#if this.firstPost}}
          <section class="embed-topic-actions__menu">
            <PostMenu
              @canCreatePost={{false}}
              @post={{this.firstPost}}
              @showLogin={{this.showLogin}}
              @toggleLike={{this.toggleLike}}
            />
          </section>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
