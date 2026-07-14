import Component from "@glimmer/component";
import { service } from "@ember/service";
import DPostAccordion from "discourse/ui-kit/d-post-accordion";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import SolvedAccordionItemMetadata from "./solved-accordion-item-metadata";

const CHARS_PER_LINE = 90;

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
      return null;
    }

    return Math.max(1, Math.ceil(chars / CHARS_PER_LINE));
  }

  <template>
    <DPostAccordion
      @posts={{this.acceptedAnswers}}
      @decoratorState={{@decoratorState}}
      @linesDisplayed={{this.linesDisplayed}}
      class="accepted-answers"
    >
      <:header>
        <h3 class="accepted-answers__title">

          {{#if this.hasAnswer}}
            {{dIcon "far-square-check"}}
          {{/if}}

          {{i18n "solved.title"}}
        </h3>

        {{#if this.hasMultipleAnswers}}
          <span class="accepted-answers__solution-count">
            {{this.acceptedAnswers.length}}
            {{i18n "solved.solution_summary" count=this.acceptedAnswers.length}}
          </span>
        {{/if}}
      </:header>

      <:itemMetadata as |post|>
        <SolvedAccordionItemMetadata @post={{post}} />
      </:itemMetadata>
    </DPostAccordion>
  </template>
}
