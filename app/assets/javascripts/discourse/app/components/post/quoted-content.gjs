import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { eq, lt, or } from "truth-helpers";
import AsyncContent from "discourse/components/async-content";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import element from "discourse/helpers/element";
import elementClass from "discourse/helpers/element-class";
import { ajax } from "discourse/lib/ajax";
import { makeArray } from "discourse/lib/helpers";
import highlightHTML from "discourse/lib/highlight-html";
import { postUrl } from "discourse/lib/utilities";
import PostCookedHtml from "./cooked-html";

export default class PostQuotedContent extends Component {
  @service store;

  @tracked
  expanded =
    this.args.decoratorState?.[`${this.args.quoteId}--expanded`] ??
    this.args.expanded ??
    false;

  #highlightOriginalText = (cookedElement) => {
    if (!this.expanded) {
      return;
    }

    // to highlight the quoted text inside the original post content
    highlightHTML(cookedElement, this.args.originalText, {
      matchCase: true,
    });
  };

  #quotedPost = this.args.decoratorState?.[`${this.args.quoteId}--post`];
  #wrapperElement;

  get extraDecorators() {
    return [
      ...makeArray(this.args.extraDecorators),
      this.#highlightOriginalText,
    ];
  }

  get isQuotedPostIgnored() {
    return this.args.ignoredUsers?.includes(this.args.quotedUsername);
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
    return this.args.id && !this.args.fullQuote && !this.isQuotedPostIgnored;
  }

  get wrapperElement() {
    return this.args.wrapperElement ?? this.#wrapperElement;
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
    if (this.args.decoratorState) {
      this.args.decoratorState[`${this.args.quoteId}--post`] = post;
    }

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
  setWrapperElement(wrapperElement) {
    this.#wrapperElement = wrapperElement;
  }

  @action
  toggleExpanded() {
    this.expanded = !this.expanded;
    if (this.args.decoratorState) {
      this.args.decoratorState[`${this.args.quoteId}--expanded`] =
        this.expanded;
    }
  }

  get WrapperComponent() {
    return this.args.wrapperElement ? element("") : element("aside");
  }

  <template>
    <this.WrapperComponent
      ...attributes
      class={{concatClass
        "quote"
        (if @quotedPostNotFound "quote-post-not-found")
      }}
      data-username={{@quotedUsername}}
      data-post={{@quotedPostNumber}}
      data-topic={{@quotedTopicId}}
      data-full={{@fullQuote}}
      {{didInsert this.setWrapperElement}}
    >
      {{! `this.WrapperComponent` can be empty to render only the children while decorating cooked content.
          that's why we're adding the class this way}}
      {{~#if this.isQuotedPostIgnored~}}
        {{elementClass "ignored-user" target=this.wrapperElement}}
      {{~/if~}}
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
        {{~#if (has-block "title")~}}
          {{~yield to="title"~}}
        {{~else~}}
          {{~#if @quotedPostNotFound~}}
            {{~@quotedUsername~}}
          {{~else~}}
            {{~@title~}}
          {{~/if~}}
        {{~/if~}}
        <div class="quote-controls">
          {{~#if this.shouldDisplayToggleButton~}}
            <DButton
              class="btn-flat quote-toggle"
              @action={{this.toggleExpanded}}
              @ariaControls={{@quoteId}}
              @ariaExpanded={{this.expanded}}
              @title="post.expand_collapse"
            >
              {{! rendering the icon in the block instead of using the parameter `@icon` prevents DButton from adding
                  extra whitespace that will interfere with the text captured when quoting a quoted content }}
              {{~icon (if this.expanded "chevron-up" "chevron-down")~}}
            </DButton>
          {{~/if~}}
          {{~#if this.shouldDisplayNavigateToPostButton~}}
            <DButton
              class="btn-flat back"
              @href={{this.quotedPostUrl}}
              @title="post.follow_quote"
            >
              {{! rendering the icon in the block instead of using the parameter `@icon` prevents DButton from adding
                  extra whitespace that will interfere with the text captured when quoting a quoted content }}
              {{~icon
                (if
                  (lt @post.post_number @quotedPostNumber)
                  "arrow-down"
                  "arrow-up"
                )
              ~}}
            </DButton>
          {{~/if~}}
        </div>
      </div>
      <blockquote id={{@id}}>
        {{~#unless this.isQuotedPostIgnored~}}
          {{~#if this.expanded~}}
            <AsyncContent
              @asyncData={{this.loadQuotedPost}}
              @context={{hash
                topicNumber=@quotedTopicId
                postNumber=@quotedPostNumber
                cachedPost=@quotedPost
              }}
            >
              <:content as |expandedPost|>
                <div class="expanded-quote" data-post-id={{expandedPost.id}}>
                  <PostCookedHtml
                    @post={{expandedPost}}
                    @decoratorState={{@decoratorState}}
                    @extraDecorators={{this.extraDecorators}}
                    @highlightTerm={{@highlightTerm}}
                    @streamElement={{false}}
                  />
                </div>
              </:content>
              <:error as |error AsyncContentInlineErrorMessage|>
                {{~#if (eq error.jqXHR.status 403)~}}
                  <div class="quote-error expanded-quote icon-only">
                    {{~icon "lock"~}}
                  </div>
                {{~else if (eq error.jqXHR.status 404)~}}
                  <div class="quote-error expanded-quote icon-only">
                    {{~icon "trash-can"~}}
                  </div>
                {{~else~}}
                  <div class="quote-error expanded-quote">
                    <AsyncContentInlineErrorMessage />
                  </div>
                {{~/if~}}
              </:error>
            </AsyncContent>
          {{~else~}}
            {{~@collapsedContent~}}
          {{~/if~}}
        {{~/unless~}}
      </blockquote>
    </this.WrapperComponent>
  </template>
}
