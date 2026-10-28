import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { toggleFlatRepliesPreference } from "discourse/lib/nested-view-preference";
import DButton from "discourse/ui-kit/d-button";

export default class NestedViewToggle extends Component {
  @service currentUser;
  @service keyValueStore;
  @service router;

  @action
  async toggle() {
    try {
      await toggleFlatRepliesPreference({
        currentUser: this.currentUser,
        keyValueStore: this.keyValueStore,
        router: this.router,
        topic: this.args.topic,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    {{#if @topic.is_nested_view}}
      {{#if @topic.rendersNested}}
        <DButton
          class="btn-flat nested-view-toggle --to-flat"
          @action={{this.toggle}}
          @icon="bars"
          @label="nested_replies.flat_view"
          @title="nested_replies.flat_view_title"
        />
      {{else}}
        <DButton
          class="btn-flat nested-view-toggle --to-nested"
          @action={{this.toggle}}
          @icon="bars-staggered"
          @label="nested_replies.nested_view"
          @title="nested_replies.nested_view_title"
        />
      {{/if}}
    {{/if}}
  </template>
}
