import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import AsyncContent from "discourse/components/async-content";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import PostCookedHtml from "../../components/post/cooked-html";

// TODO (glimmer-post-stream): investigate whether all this complex logic can be replaced with a proper Glimmer component
export default function (element, context) {
  const { data, state } = context;

  const quotes = element.querySelectorAll("aside.quote");
  if (quotes.length === 0) {
    return;
  }

  quotes.forEach((aside, index) => {
    if (aside.dataset.post) {
      const quotedTopicNumber = parseInt(
        aside.dataset.topic || data.post.topic_id,
        10
      );
      const quotedPostNumber = parseInt(aside.dataset.post, 10);

      const quoteId = `quote-id-${quotedTopicNumber}-${quotedPostNumber}-${index}`;

      const postNotFound = aside.classList.contains("quote-post-not-found");
      const username = aside.dataset.username;

      let title = aside.querySelector(".title");

      // extract the title HTML without the quote controls DIV
      if (title) {
        title.querySelector(".quote-controls").remove();
        title = htmlSafe(title.innerHTML);
      }

      const content = htmlSafe(aside.querySelector("blockquote")?.innerHTML);

      context.helper.renderGlimmer(
        aside,
        QuotedContent,
        {
          id: quoteId,
          highlightTerm: data.highlightTerm,
          content,
          title,
          expanded:
            state[`${quoteId}--expanded`] ?? aside.dataset.expanded === "true",
          post: data.post,
          quotedTopicNumber,
          quotedPostNumber,
          quotedPost: state[`${quoteId}--post`],
          onLoadQuotedPost: (post) => {
            state[`${quoteId}--post`] = post;
          },
          onToggleExpanded: (value) => {
            state[`${quoteId}--expanded`] = value;
          },
          state,
        },
        { append: false }
      );
    }
  });
}

class QuotedContent extends Component {
  @service store;

  @tracked expanded = this.args.data.expanded ?? false;
  #quotedPost = this.args.data.quotedPost;

  @action
  toggleExpanded() {
    this.expanded = !this.expanded;
    this.args.data.onToggleExpanded?.(this.expanded);
  }

  @action
  async loadQuotedPost({ topicNumber, postNumber }) {
    if (
      this.#quotedPost?.topic_id === topicNumber &&
      this.#quotedPost?.post_number === postNumber
    ) {
      console.log("cached", this.#quotedPost);
      return this.#quotedPost;
    }

    const post = this.store.createRecord(
      "post",
      await ajax(`/posts/by_number/${topicNumber}/${postNumber}`)
    );

    if (post.topic_id === this.args.data.post?.topic_id) {
      post.topic = this.args.data.post.topic;
    }

    this.#quotedPost = post;
    this.args.data.onLoadQuotedPost?.(post);

    return post;
  }

  <template>
    <div
      class="title"
      data-has-quote-controls="true"
      {{on "click" this.toggleExpanded}}
    >
      {{@data.title}}
      <div class="quote-controls">
        <button
          aria-controls={{@quoteId}}
          aria-expanded={{this.expanded}}
          class="btn quote-toggle btn-flat"
          type="button"
          {{on "click" this.toggleExpanded}}
        >
          {{icon
            (if this.expanded "chevron-up" "chevron-down")
            title="post.expand_collapse"
          }}
        </button>
      </div>
    </div>
    <blockquote id={{@data.id}}>
      {{#if this.expanded}}
        <AsyncContent
          @asyncData={{this.loadQuotedPost}}
          @context={{hash
            topicNumber=@data.quotedTopicNumber
            postNumber=@data.quotedPostNumber
            cachedPost=@data.quotedPost
          }}
        >
          <:error as |error|>
            <div class="quote-error expanded-quote icon-only">
              {{#if (eq error.jqXHR.status 403)}}
                {{icon "lock" title="errors.quoted_post_inaccessible"}}
              {{else if (eq error.jqXHR.status 404)}}
                {{icon "trash-can" title="errors.quoted_post_not_found"}}
              {{else}}
                {{icon
                  "exclamation-triangle"
                  title="errors.loading_quoted_post"
                }}
              {{/if}}
            </div>
          </:error>

          <:content as |expandedPost|>
            <PostCookedHtml
              @post={{expandedPost}}
              @highlightTerm={{@data.highlightTerm}}
              @streamElement={{false}}
              @state={{@data.state}}
            />
          </:content>
        </AsyncContent>
      {{else}}
        {{@data.content}}
      {{/if}}
    </blockquote>
  </template>
}
