import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export default class PostMenuShowMoreButton extends Component {
  static shouldRender(args) {
    return args.context.collapsedButtons.length && args.context.collapsed;
  }

  <template>
    {{#if @shouldRender}}
      <DButton
        class="post-action-menu__show-more show-more-actions"
        ...attributes
        @action={{@buttonActions.showMoreActions}}
        @icon="ellipsis-h"
        @title="show_more"
      />
    {{/if}}
  </template>
}
