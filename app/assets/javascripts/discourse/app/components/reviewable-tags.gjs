import Component from "@ember/component";
import discourseTag from "discourse/helpers/discourse-tag";

export default class ReviewableTags extends Component {
  <template>
    {{#if this.tags}}
      <div class="list-tags">
        {{#each this.tags as |t|}}{{discourseTag t}}{{/each}}
      </div>
    {{/if}}
  </template>
}
