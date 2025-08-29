import { on } from "@ember/modifier";
import { i18n } from "discourse-i18n";

const TopicSkipLinks = <template>
  <div class="skip-links" aria-label={{i18n "skip_links_label"}}>
    {{#if @controller.isDirectUrlToArbitraryPost}}
      <a
        href="{{@controller.topicUrl}}/{{@controller.currentPostNumber}}"
        class="skip-link"
        {{on "click" @controller.handleSkipToPost}}
      >
        {{i18n "skip_to_post" post_number=@controller.currentPostNumber}}
      </a>
    {{/if}}
    {{#if @controller.resumePostNumber}}
      {{#if @controller.resumeIsLastReply}}
        <a
          href="{{@controller.topicUrl}}/last"
          class="skip-link"
          {{on "click" @controller.handleSkipToResume}}
        >
          {{i18n
            "skip_to_where_you_left_off_last"
            post_number=@controller.resumePostNumber
          }}
        </a>
      {{else}}
        <a
          href="{{@controller.topicUrl}}/{{@controller.resumePostNumber}}"
          class="skip-link"
          {{on "click" @controller.handleSkipToResume}}
        >
          {{i18n
            "skip_to_where_you_left_off"
            post_number=@controller.resumePostNumber
          }}
        </a>
        {{#if @controller.topicHasMultiplePosts}}
          <a
            href="{{@controller.topicUrl}}/last"
            class="skip-link"
            {{on "click" @controller.handleSkipToLastPost}}
          >{{i18n "skip_to_last_reply"}}</a>
        {{/if}}
      {{/if}}
    {{else}}
      {{#if @controller.topicHasMultiplePosts}}
        <a
          href="{{@controller.topicUrl}}/last"
          class="skip-link"
          {{on "click" @controller.handleSkipToLastPost}}
        >{{i18n "skip_to_last_reply"}}</a>
      {{/if}}
    {{/if}}
    {{#if @controller.topicHasMultiplePosts}}
      <a
        href="{{@controller.topicUrl}}/1"
        class="skip-link"
        {{on "click" @controller.handleSkipToTop}}
      >{{i18n "skip_to_top"}}</a>
    {{/if}}
    <a href="#main-container" class="skip-link">{{i18n
        "skip_to_main_content"
      }}</a>
  </div>
</template>;

export default TopicSkipLinks;
