import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export default class PostMenuShowMoreButton extends Component {
  static shouldRender(args) {
    return args.state.collapsedButtons.length && args.state.collapsed;
  }

  <template>
    <DButton
      class="post-action-menu__show-more show-more-actions"
      ...attributes
      @action={{@buttonActions.showMoreActions}}
      @icon="ellipsis-h"
      @title="show_more"
    />
  </template>
}
