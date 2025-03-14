import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import AsyncContent from "discourse/components/async-content";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";

export default class DiscoveryFilterNavigationTags extends Component {
  iteration = 1;

  get query() {
    return this.args.query || "";
  }

  @action
  async loadTags() {
    const data = { q: this.query || "" };
    const request = await ajax("/tags/filter/search", { data });
    const tagsMap = new Map();
    request.results.forEach((result) => {
      tagsMap.set(result.name, {
        name: result.name,
        selected: this.args.tags?.includes?.(result.name) || false,
      });
    });
    this.args.tags?.forEach((tagName) => {
      if (tagsMap.has(tagName)) {
        tagsMap.get(tagName).selected = true;
      } else {
        tagsMap.set(tagName, {
          name: tagName,
          selected: true,
        });
      }
    });
    return Array.from(tagsMap.values()).sort((a, b) =>
      a.name.localeCompare(b.name)
    );
  }

  @action
  toggleTag(tag) {
    const selectedTags = [...(this.args.tags || [])];

    if (tag.selected) {
      const index = selectedTags.indexOf(tag.name);
      if (index !== -1) {
        selectedTags.splice(index, 1);
      }
    } else {
      if (!selectedTags.includes(tag.name)) {
        selectedTags.push(tag.name);
      }
    }

    this.args.onChange?.(selectedTags);
  }

  <template>
    <AsyncContent @asyncData={{this.loadTags}}>
      <:loading></:loading>
      <:content as |tags|>
        <div class="filter-navigation__tags-list">
          {{#each tags as |tag|}}
            <DButton
              @action={{fn this.toggleTag tag}}
              class={{concatClass (if tag.selected "btn-primary")}}
            >{{tag.name}}</DButton>
          {{/each}}
        </div>
      </:content>
    </AsyncContent>
  </template>
}
