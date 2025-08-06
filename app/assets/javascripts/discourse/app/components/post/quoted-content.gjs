import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import { eq } from "truth-helpers";
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
    this.args.decoratorState?.get(this.stateExpandedId) ??
    this.args.expanded ??
    false;

  applyWrapperDataAttributes = modifierFn((_, [target], data) => {
    const attributes = Object.entries(data);
    if (!target || attributes.length === 0) {
      return null;
    }
    const originalValues = {};
    attributes.forEach(([key, value]) => {
      originalValues[key] = target.dataset[key];
      target.dataset[key] = value;
    });
    return () => {
      // restore the original values
      Object.entries(originalValues).forEach(([key, value]) => {
        if (value === undefined) {
          delete target.dataset[key];
        } else {
          target.dataset[key] = value;
        }
      });
    };
  });

  #quotedPost = this.args.decoratorState?.get(this.statePostId);

  #highlightOriginalText = (cookedElement) => {
    if (!this.expanded) {
      return;
    }
    // to highlight the quoted text inside the original post content
    highlightHTML(cookedElement, this.args.originalText, {
      matchCase: true,
    });
  };

  get extraDecorators() {
    return [
      ...makeArray(this.args.extraDecorators),
      this.#highlightOriginalText,
    ];
  }

  get isQuotedPostIgnored() {
    return this.args.ignoredUsers?.includes(this.args.quotedUsername);
  }

  get navigateToPostIcon() {
    if (!this.args.post) {
      return "arrow-down";
    }
    return this.args.post.post_number < this.args.quotedPostNumber
      ? "arrow-down"
      : "arrow-up";
  }

  get quotedPostUrl() {
    const { quotedTopicId, post, quotedPostNumber } = this.args;
    if (quotedTopicId !== post?.topic?.id) {
      return null;
    }

    const slug = post?.topic?.slug;
    if (quotedPostNumber && slug) {
      return postUrl(slug, quotedTopicId, quotedPostNumber);
    }
    return null;
  }

  get shouldDisplayNavigateToPostButton() {
    return !this.args.quotedPostNotFound && this.quotedPostUrl;
  }

  get shouldDisplayQuoteControls() {
    return (
      this.shouldDisplayNavigateToPostButton || this.shouldDisplayToggleButton
    );
  }

  get shouldDisplayToggleButton() {
    return (
      !this.args.quotedPostNotFound &&
      this.args.id &&
      !this.args.fullQuote &&
      !this.isQuotedPostIgnored
    );
  }

  get stateExpandedId() {
    return `${this.args.id}--expanded`;
  }

  get statePostId() {
    return `${this.args.id}--post`;
  }

  get toggleIcon() {
    return this.expanded ? "chevron-up" : "chevron-down";
  }

  get OptionalWrapperComponent() {
    return this.args.wrapperElement ? element("") : element("aside");
  }

  @action
  async loadQuotedPost({ topicNumber, postNumber }) {
    if (
      this.#quotedPost?.topic_id === topicNumber &&
      this.#quotedPost?.post_number === postNumber
    ) {
      return this.#quotedPost;
    }
    const url = `/posts/by_number/${topicNumber}/${postNumber}`;
    const post = this.store.createRecord(
      "post",
      await ajax(url, {
        ignoreUnsent: false,
      })
    );
    if (post.topic_id === this.args.post?.topic_id) {
      post.topic = this.args.post.topic;
    }
    this.#quotedPost = post;
    this.args.decoratorState?.set(this.statePostId, post);
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
    this.args.decoratorState?.set(this.stateExpandedId, this.expanded);
  }

  <template>
    {{! template-lint-disable no-unnecessary-concat }}
    <this.OptionalWrapperComponent
      ...attributes
      class={{concatClass
        "quote"
        (if @quotedPostNotFound "quote-post-not-found")
        (if this.isQuotedPostIgnored "ignored-user")
      }}
      {{! forced quotes in the data-attributes below to cast the boolean values to string }}
      data-expanded="{{this.expanded}}"
      data-full="{{@fullQuote}}"
      data-post={{@quotedPostNumber}}
      data-topic={{@quotedTopicId}}
      data-username={{@quotedUsername}}
    >
      {{#if @wrapperElement}}
        {{! `this.OptionalWrapperComponent` can be empty to render only the children while decorating cooked content.
        we need to handle the attributtes below in the existing wrapper received as @wrapperElement in this case }}
        {{elementClass
          (if this.isQuotedPostIgnored "ignored-user")
          target=@wrapperElement
        }}
      {{/if}}
      <div
        class="title"
        data-has-quote-controls={{this.shouldDisplayQuoteControls}}
        data-can-toggle-quote={{this.shouldDisplayToggleButton}}
        data-can-navigate-to-post={{this.shouldDisplayNavigateToPostButton}}
        {{(if
          this.shouldDisplayToggleButton (modifier on "click" this.onClickTitle)
        )}}
        {{(if
          @wrapperElement
          (modifier
            this.applyWrapperDataAttributes
            @wrapperElement
            expanded=this.expanded
          )
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
        {{~#if this.shouldDisplayQuoteControls~}}
          <div class="quote-controls">
            {{~#if this.shouldDisplayToggleButton~}}
              <DButton
                class="btn-flat quote-toggle"
                @action={{this.toggleExpanded}}
                @ariaControls={{@id}}
                @ariaExpanded={{this.expanded}}
                @ariaLabel={{if this.expanded "post.collapse" "expand"}}
                @title={{if this.expanded "post.collapse" "expand"}}
              >
                {{! rendering the icon in the block instead of using the parameter `@icon` prevents DButton from adding
                    extra whitespace that will interfere with the text captured when quoting a quoted content }}
                {{~icon this.toggleIcon~}}
              </DButton>
            {{~/if~}}
            {{~#if this.shouldDisplayNavigateToPostButton~}}
              <DButton
                class="btn-flat back"
                @href={{this.quotedPostUrl}}
                @title="post.follow_quote"
                @ariaLabel="post.follow_quote"
              >
                {{! rendering the icon in the block instead of using the parameter `@icon` prevents DButton from adding
                    extra whitespace that will interfere with the text captured when quoting a quoted content }}
                {{~icon this.navigateToPostIcon~}}
              </DButton>
            {{~/if~}}
          </div>
        {{~/if~}}
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
                    @className="post__contents-cooked-quote"
                    @post={{expandedPost}}
                    @decoratorState={{@decoratorState}}
                    @extraDecorators={{this.extraDecorators}}
                    @highlightTerm={{@highlightTerm}}
                    @selectionBarrier={{false}}
                    @streamElement={{@streamElement}}
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
            <PostCookedHtml
              @className="post__contents-cooked-quote"
              @post={{@post}}
              @cooked={{@collapsedContent}}
              @decoratorState={{@decoratorState}}
              @extraDecorators={{this.extraDecorators}}
              @highlightTerm={{@highlightTerm}}
              @selectionBarrier={{false}}
              @streamElement={{@streamElement}}
            />
          {{~/if~}}
        {{~/unless~}}
      </blockquote>
    </this.OptionalWrapperComponent>
  </template>
}
