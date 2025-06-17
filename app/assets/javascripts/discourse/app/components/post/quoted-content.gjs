import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq, or } from "truth-helpers";
import AsyncContent from "discourse/components/async-content";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import elementClass from "discourse/helpers/element-class";
import { ajax } from "discourse/lib/ajax";
import { postUrl } from "discourse/lib/utilities";
import PostCookedHtml from "./cooked-html";

export default class PostQuotedContent extends Component {
  @service store;

  @tracked expanded = this.args.expanded ?? false;
  #quotedPost = this.args.quotedPost;

  get isQuotedPostIgnored() {
    return this.args.ignoredUsers?.includes(this.args.username);
  }

  get quotedPostUrl() {
    const topicId = this.args.quotedTopicId;

    // only display the navigation button when the post belongs to the same topic
    if (topicId !== this.args.post?.topic?.id) {
      return;
    }

    const postNumber = this.args.quotedPostNumber;
    const slug = this.args.post.topic.slug;

    if (postNumber) {
      return postUrl(slug, topicId, postNumber);
    }
  }

  get shouldDisplayNavigateToPostButton() {
    return this.quotedPostUrl && !this.isQuotedPostIgnored;
  }

  get shouldDisplayToggleButton() {
    return this.args.id && !this.args.full && !this.isQuotedPostIgnored;
  }

  @action
  async loadQuotedPost({ topicNumber, postNumber }) {
    if (
      this.#quotedPost?.topic_id === topicNumber &&
      this.#quotedPost?.post_number === postNumber
    ) {
      return this.#quotedPost;
    }

    const post = this.store.createRecord(
      "post",
      await ajax(`/posts/by_number/${topicNumber}/${postNumber}`, {
        ignoreUnsent: false,
      })
    );

    if (post.topic_id === this.args.post?.topic_id) {
      post.topic = this.args.post.topic;
    }

    this.#quotedPost = post;
    this.args.onLoadQuotedPost?.(post);

    return post;
  }

  @action
  onClickTitle(event) {
    if (event.target.closest("a") || event.target.closest(".quote-controls")) {
      return;
    }

    this.toggleExpanded();
  }

  @action
  toggleExpanded() {
    this.expanded = !this.expanded;
    this.args.onToggleExpanded?.(this.expanded);
  }

  <template>
    {{#if this.isQuotedPostIgnored}}
      {{elementClass "ignored-user" target=@parentElement}}
    {{/if}}
    <div
      class="title"
      data-has-quote-controls={{or
        this.shouldDisplayToggleButton
        this.shouldDisplayNavigateToPostButton
      }}
      data-can-toggle-quote={{this.shouldDisplayToggleButton}}
      {{(if
        this.shouldDisplayToggleButton (modifier on "click" this.onClickTitle)
      )}}
    >
      {{#if @quotedPostNotFound}}
        {{@username}}
      {{else}}
        {{@title}}
      {{/if}}
      <div class="quote-controls">
        {{#if this.shouldDisplayToggleButton}}
          <DButton
            class="btn-flat quote-toggle"
            @action={{this.toggleExpanded}}
            @ariaControls={{@quoteId}}
            @ariaExpanded={{this.expanded}}
            @icon={{if this.expanded "chevron-up" "chevron-down"}}
            @title="post.expand_collapse"
          />
        {{/if}}
        {{#if this.shouldDisplayNavigateToPostButton}}
          <DButton
            class="btn-flat back"
            @href={{this.quotedPostUrl}}
            @icon="arrow-up"
            @title="post.follow_quote"
          />
        {{/if}}
      </div>
    </div>
    <blockquote id={{@id}}>
      {{#unless this.isQuotedPostIgnored}}
        {{#if this.expanded}}
          <AsyncContent
            @asyncData={{this.loadQuotedPost}}
            @context={{hash
              topicNumber=@quotedTopicId
              postNumber=@quotedPostNumber
              cachedPost=@quotedPost
            }}
          >
            <:error as |error AsyncContentInlineErrorMessage|>
              {{#if (eq error.jqXHR.status 403)}}
                <div class="quote-error expanded-quote icon-only">
                  {{icon "lock"}}
                </div>
              {{else if (eq error.jqXHR.status 404)}}
                <div class="quote-error expanded-quote icon-only">
                  {{icon "trash-can"}}
                </div>
              {{else}}
                <div class="quote-error expanded-quote">
                  <AsyncContentInlineErrorMessage />
                </div>
              {{/if}}
            </:error>

            <:content as |expandedPost|>
              <div class="expanded-quote" data-post-id="{{expandedPost.id}}">
                <PostCookedHtml
                  @post={{expandedPost}}
                  @highlightTerm={{@highlightTerm}}
                  @streamElement={{false}}
                  @state={{@state}}
                />
              </div>
            </:content>
          </AsyncContent>
        {{else}}
          {{@content}}
        {{/if}}
      {{/unless}}
    </blockquote>
  </template>
}
