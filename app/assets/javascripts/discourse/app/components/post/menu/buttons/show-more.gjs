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
        @action={{@action}}
        @icon="ellipsis-h"
        @title="show_more"
      />
    {{/if}}
  </template>
}
