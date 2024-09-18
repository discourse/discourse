import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

export default class PostMenuEditButton extends Component {
  static alwaysShow(args) {
    return args.context.isWikiMode || (args.post.can_edit && args.post.yours);
  }

  static shouldRender(args) {
    return args.post.can_edit;
  }

  @service site;

  get showLabel() {
    return (
      this.args.showLabel ??
      (this.site.desktopView && this.args.context.isWikiMode)
    );
  }

  <template>
    {{#if @shouldRender}}
      <DButton
        class={{concatClass "edit" (if @post.wiki "create")}}
        ...attributes
        @action={{@buttonActions.editPost}}
        @icon={{if @post.wiki "far-edit" "pencil-alt"}}
        @label={{if this.showLabel "post.controls.edit_action"}}
        @title="post.controls.edit"
      />
    {{/if}}
  </template>
}
