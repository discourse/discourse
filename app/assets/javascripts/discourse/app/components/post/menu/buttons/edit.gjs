import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

export default class PostMenuEditButton extends Component {
  static hidden(args) {
    if (args.state.isWikiMode || (args.post.can_edit && args.post.yours)) {
      return false;
    }

    // returning null here allows collapseByDefault to fallback to the value configured in the settings for the button
    return null;
  }

  static shouldRender(args) {
    return args.post.can_edit;
  }

  @service site;

  get showLabel() {
    return (
      this.args.showLabel ??
      (this.site.desktopView && this.args.state.isWikiMode)
    );
  }

  <template>
    <DButton
      class={{concatClass
        "post-action-menu__edit"
        "edit"
        (if @post.wiki "create")
      }}
      ...attributes
      @action={{@buttonActions.editPost}}
      @icon={{if @post.wiki "far-edit" "pencil"}}
      @label={{if this.showLabel "post.controls.edit_action"}}
      @title="post.controls.edit"
    />
  </template>
}
