import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

export default class PostMenuEditButton extends Component {
  static shouldRender(post) {
    return post.can_edit;
  }

  <template>
    {{#if @shouldRender}}
      <DButton
        class={{concatClass "edit" (if @post.wiki "create")}}
        ...attributes
        @action={{@action}}
        @icon={{if @post.wiki "far-edit" "pencil-alt"}}
        @label={{if @showLabel "post.controls.edit_action"}}
        @title="post.controls.edit"
      />
    {{/if}}
  </template>
}
