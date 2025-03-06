import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import AsyncContent from "discourse/components/async-content";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";

export default class DiscoveryFilterNavigationTags extends Component {
  @action
  async loadTags() {
    console.log("load tags?");
    const data = { q: "baz" || "" };
    const flattenedTags = this.args.data.tags.map((tag) => tag.name);
    const request = await ajax("/tags/filter/search", { data });

    this.args.data.tags.forEach((tag, index) => {
      if (!tag.selected) {
        this.collection.remove(index);
      }
    });

    request.results.filter((result) => {
      if (!flattenedTags.includes(result.name)) {
        this.collection.add(result);
      }
    });
  }

  @action
  onRegisterApi(api) {
    this.collection = api;
  }

  @action
  toggleTag(data) {
    data.selected = true;
  }

  <template>
    <@form.Collection
      {{didInsert this.loadTags "baz"}}
      @onRegisterApi={{this.onRegisterApi}}
      @name="tags"
      as |collection index collectionData|
    >
      <collection.Field
        @name="name"
        @title="name"
        @showTitle={{false}}
        as |field|
      >
        <field.Custom>
          <DButton
            @translatedLabel={{collectionData.name}}
            @action={{fn this.toggleTag collectionData}}
            @icon="tag"
            class={{if collectionData.selected "btn-primary"}}
          />
        </field.Custom>
      </collection.Field>
    </@form.Collection>
  </template>
}
