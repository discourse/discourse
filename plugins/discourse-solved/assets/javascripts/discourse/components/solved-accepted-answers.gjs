import Component from "@glimmer/component";
import PostExcerptAccordion from "discourse/components/post/post-excerpt-accordion";
import icon from "discourse/helpers/d-icon";
import Post from "discourse/models/post";
import { i18n } from "discourse-i18n";
import SolvedAccordionItemMetadata from "./solved-accordion-item-metadata";

export default class SolvedAcceptedAnswers extends Component {
  static shouldRender(args) {
    return (
      args.post?.post_number === 1 &&
      args.post?.topic?.accepted_answers?.length > 0
    );
  }

  get topic() {
    return this.args.post.topic;
  }

  get acceptedAnswers() {
    return (this.topic.accepted_answers ?? []).map((answer) => {
      const post = Post.create(answer);
      post.topic = this.topic;
      return post;
    });
  }

  get hasAnswer() {
    return !!this.acceptedAnswers;
  }

  get hasMultipleAnswers() {
    return this.acceptedAnswers?.length > 1;
  }

  <template>
    <PostExcerptAccordion
      @excerptPosts={{this.acceptedAnswers}}
      @decoratorState={{@decoratorState}}
      class="d-solved-answers"
    >
      <:accordionHeader>
        <h3 class="d-solved-answers__title">

          {{#if this.hasAnswer}}
            {{icon "far-square-check"}}
          {{/if}}

          {{i18n "solved.title"}}
        </h3>

        {{#if this.hasMultipleAnswers}}
          {{this.acceptedAnswers.length}}
          {{i18n "solved.solution_summary" count=this.acceptedAnswers.length}}
        {{/if}}
      </:accordionHeader>

      <:accordionItemMetadata as |excerptPost|>
        <SolvedAccordionItemMetadata @excerptPost={{excerptPost}} />
      </:accordionItemMetadata>
    </PostExcerptAccordion>
  </template>
}
