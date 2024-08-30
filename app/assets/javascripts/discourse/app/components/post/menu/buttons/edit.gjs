import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class PostMenuEditButton extends Component {
  @service site;

  <template>
    {{#if @transformedPost.canEdit}}
      <DButton
        class="edit create"
        ...attributes
        @icon={{if @transformedPost.wiki "far-edit" "pencil-alt"}}
        @title="post.controls.edit"
        @label={{if @properties.showLabel "post.controls.edit_action"}}
        @action={{@action}}
      />
    {{/if}}
  </template>
}
