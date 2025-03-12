import Component from "@ember/component";

export default class ReviewableTags extends Component {}

{{#if this.tags}}
  <div class="list-tags">
    {{#each this.tags as |t|}}{{discourse-tag t}}{{/each}}
  </div>
{{/if}}