import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { Promise } from "rsvp";
import DButton from "discourse/components/d-button";
import routeAction from "discourse/helpers/route-action";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import PostVotingCommentsMenuComposer from "./post-voting-comments-menu-composer";

export default class PostVotingCommentsMenu extends Component {
  @service currentUser;

  @tracked expanded = false;

  get hasMoreComments() {
    return this.args.moreCommentCount > 0;
  }

  @action
  handleSave(comment) {
    this.closeComposer();
    this.args.appendComments([comment]);
  }

  @action
  expandComposer() {
    this.expanded = true;

    this.fetchComments().then(() => {
      schedule("afterRender", () => {
        const textArea = document.querySelector(
          `#post_${this.args.postNumber} .post-voting-comment-composer .post-voting-comment-composer-textarea`
        );
        textArea.focus();
        textArea.select();
      });
    });
  }

  @action
  closeComposer() {
    this.expanded = false;
  }

  @action
  fetchComments() {
    if (!this.args.id) {
      return Promise.resolve();
    }

    const data = {
      post_id: this.args.id,
      last_comment_id: this.args.lastCommentId,
    };

    return ajax("/post_voting/comments", {
      type: "GET",
      data,
    })
      .then((response) => {
        if (response.comments.length > 0) {
          this.args.appendComments(response.comments);
        }
      })
      .catch(popupAjaxError);
  }

  <template>
    <div class="post-voting-comments-menu">
      {{#if this.expanded}}
        <PostVotingCommentsMenuComposer
          @id={{@id}}
          @onSave={{this.handleSave}}
          @onCancel={{this.closeComposer}}
        />
      {{else}}
        <DButton
          @display="link"
          @action={{if
            this.currentUser
            this.expandComposer
            (routeAction "showLogin")
          }}
          @label="post_voting.post.post_voting_comment.add"
          class="post-voting-comment-add-link"
        />
      {{/if}}

      {{#if this.hasMoreComments}}
        {{#unless this.expanded}}
          <span class="post-voting-comments-menu-separator"></span>
        {{/unless}}

        <div class="post-voting-comments-menu-show-more">
          <DButton
            @display="link"
            @action={{this.fetchComments}}
            @translatedLabel={{i18n
              "post_voting.post.post_voting_comment.show"
              count=@moreCommentCount
            }}
            class="post-voting-comments-menu-show-more-link"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
