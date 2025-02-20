import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import AsyncContent from "discourse/components/async-content";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";

export default class DiscoveryFilterNavigationTags extends Component {
  @action
  async loadTags({ query, tags }) {
    const data = { q: query || "" };
    const flattenedTags = tags.map((tag) => tag.name);
    const request = await ajax("/tags/filter/search", { data });

    return request.results.filter(
      (result) => !flattenedTags.includes(result.name)
    );
  }

  <template>
    <@form.Collection @name="tags" as |collection index collectionData|>
      <collection.Field
        @name="name"
        @title="name"
        @showTitle={{false}}
        as |field|
      >
        <field.Custom>
          <DButton
            @translatedLabel={{collectionData.name}}
            @action={{fn collection.remove index}}
            class="btn-primary"
          />
        </field.Custom>
      </collection.Field>
    </@form.Collection>

    <AsyncContent @asyncData={{fn this.loadTags @data}}>
      <:content as |tags|>
        {{#each tags as |tag|}}
          <DButton
            @translatedLabel={{tag.name}}
            @action={{fn @form.addItemToCollection "tags" tag}}
          />
        {{/each}}
      </:content>
    </AsyncContent>
  </template>
}
