import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export default class PostMenuShowMoreButton extends Component {
  static shouldRender(post, context) {
    return context.collapsedButtons.length && context.collapsed;
  }

  <template>
    {{#if @shouldRender}}
      <DButton
        class="show-more-actions"
        ...attributes
        @title="show_more"
        @icon="ellipsis-h"
        @action={{@action}}
      />
    {{/if}}
  </template>
}
