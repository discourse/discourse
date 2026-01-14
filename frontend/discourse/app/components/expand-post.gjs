import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";

export default class ExpandPost extends Component {
  @tracked expanded = false;
  loading = false;

  @action
  async toggleItem() {
    if (this.loading) {
      return;
    }

    if (this.expanded) {
      this.expanded = false;
      this.args.item.set("expandedExcerpt", null);
      return;
    }

    this.loading = true;
    try {
      const result = await ajax(
        `/posts/by_number/${this.args.item.topic_id}/${this.args.item.post_number}.json`
      );

      this.expanded = true;
      this.args.item.set("expandedExcerpt", result.cooked);
    } finally {
      this.loading = false;
    }
  }

  <template>
    {{#if @item.truncated}}
      <DButton
        @action={{this.toggleItem}}
        @icon={{if this.expanded "chevron-up" "chevron-down"}}
        @title="post.expand_collapse"
        class={{concatClass
          "btn-transparent"
          (if this.expanded "collapse-item" "expand-item")
        }}
      />
    {{/if}}
  </template>
}
