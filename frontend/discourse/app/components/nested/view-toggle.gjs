import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { toggleFlatRepliesPreference } from "discourse/lib/nested-view-preference";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class NestedViewToggle extends Component {
  @service currentUser;
  @service keyValueStore;
  @service router;

  @action
  toggle() {
    toggleFlatRepliesPreference({
      currentUser: this.currentUser,
      keyValueStore: this.keyValueStore,
      router: this.router,
      topic: this.args.topic,
    });
  }

  <template>
    {{#if @topic.is_nested_view}}
      <DButton
        class={{dConcatClass
          "btn-flat nested-view-toggle"
          (if @topic.rendersNested "--to-flat" "--to-nested")
        }}
        @action={{this.toggle}}
        @icon={{if @topic.rendersNested "bars" "bars-staggered"}}
        @label={{if
          @topic.rendersNested
          "nested_replies.flat_view"
          "nested_replies.nested_view"
        }}
        @title={{if
          @topic.rendersNested
          "nested_replies.flat_view_title"
          "nested_replies.nested_view_title"
        }}
      />
    {{/if}}
  </template>
}
