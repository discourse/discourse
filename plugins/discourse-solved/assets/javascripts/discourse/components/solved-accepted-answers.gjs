import Component from "@glimmer/component";
import { service } from "@ember/service";
import PostExcerptAccordion from "discourse/components/post/post-excerpt-accordion";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import SolvedAccordionItemMetadata from "./solved-accordion-item-metadata";

const CHARS_PER_LINE = 90;
const DEFAULT_LINES_DISPLAYED = 14;

export default class SolvedAcceptedAnswers extends Component {
  static shouldRender(args) {
    return (
      args.post?.post_number === 1 &&
      args.post?.topic?.accepted_answers?.length > 0
    );
  }

  @service siteSettings;

  get topic() {
    return this.args.post.topic;
  }

  get acceptedAnswers() {
    return this.topic.accepted_answers ?? [];
  }

  get hasAnswer() {
    return !!this.acceptedAnswers;
  }

  get hasMultipleAnswers() {
    return this.acceptedAnswers?.length > 1;
  }

  get linesDisplayed() {
    const chars = this.siteSettings.solved_quote_length;
    if (chars <= 0) {
      return DEFAULT_LINES_DISPLAYED;
    }

    return Math.max(1, Math.ceil(chars / CHARS_PER_LINE));
  }

  <template>
    <PostExcerptAccordion
      @excerptPosts={{this.acceptedAnswers}}
      @decoratorState={{@decoratorState}}
      @linesDisplayed={{this.linesDisplayed}}
      class="d-solved-answers"
    >
      <:header>
        <h3 class="d-solved-answers__title">

          {{#if this.hasAnswer}}
            {{icon "far-square-check"}}
          {{/if}}

          {{i18n "solved.title"}}
        </h3>

        {{#if this.hasMultipleAnswers}}
          <span class="d-solved-answers__solution_count">
            {{this.acceptedAnswers.length}}
            {{i18n "solved.solution_summary" count=this.acceptedAnswers.length}}
          </span>
        {{/if}}
      </:header>

      <:itemMetadata as |excerptPost|>
        <SolvedAccordionItemMetadata @excerptPost={{excerptPost}} />
      </:itemMetadata>
    </PostExcerptAccordion>
  </template>
}
