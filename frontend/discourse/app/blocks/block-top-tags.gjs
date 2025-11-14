import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { block } from "discourse/blocks";
import dIcon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";

@block("top-tags")
export default class BlockTopTags extends Component {
  @tracked topTags;

  <template>
    <div class="block-top-tags__layout">
      <h2 clas="block-top-tags__title">{{this.blockTitle}}</h2>
      <ul class="block-top-tags__list">
        {{#each this.topTags as |tag|}}
          <li>
            {{dIcon this.tagIcon}}
            <a href="/tag/{{tag.id}}">{{tag.id}}</a></li>
        {{/each}}
      </ul>
    </div>
  </template>

  constructor() {
    super(...arguments);
    this.blockTitle = this.args?.title || "Top Tags";
    this.tagIcon = this.args?.icon || "tag";

    this.getTags();
  }

  @action
  async getTags() {
    const count = this.args?.count || 10;

    const tagsList = await ajax(`/tags.json`);
    this.topTags = tagsList.tags.slice(0, count);
  }
}
