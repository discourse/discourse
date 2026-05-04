import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import concatClass from "discourse/helpers/concat-class";
import PostExcerptAccordionItem from "./post-excerpt-accordion-item";

export default class PostExcerptAccordion extends Component {
  get topic() {
    return this.args.post.topic;
  }

  get excerptPosts() {
    return this.args.excerptPosts ?? [];
  }

  <template>
    <aside
      class={{concatClass "d-post-excerpt-accordion"}}
      data-topic={{@post.topic.id}}
    >
      <div class="d-post-excerpt-accordion__header">
        {{#if (has-block "accordionHeader")}}
          {{yield (hash excerptPosts=this.excerptPosts) to="accordionHeader"}}
        {{/if}}
      </div>

      {{#each this.excerptPosts as |excerptPost|}}
        <PostExcerptAccordionItem
          @decoratorState={{@decoratorState}}
          @excerptPost={{excerptPost}}
        />
      {{/each}}
    </aside>
  </template>
}
