import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export const BUTTON_ACTION_MODE_DELETE = "delete";
export const BUTTON_ACTION_MODE_DELETE_TOPIC = "delete-topic";
export const BUTTON_ACTION_MODE_SHOW_FLAG_DELETE = "show-flag-delete";
export const BUTTON_ACTION_MODE_RECOVER = "recover";
export const BUTTON_ACTION_MODE_RECOVER_TOPIC = "recover-topic";

export default class PostMenuDeleteButton extends Component {
  static shouldRender(post) {
    return post.can_edit;
  }

  get className() {
    switch (this.args.actionMode) {
      case BUTTON_ACTION_MODE_DELETE:
      case BUTTON_ACTION_MODE_DELETE_TOPIC:
      case BUTTON_ACTION_MODE_SHOW_FLAG_DELETE:
        return "delete";

      case BUTTON_ACTION_MODE_RECOVER:
      case BUTTON_ACTION_MODE_RECOVER_TOPIC:
        return "recover";
    }
  }

  get icon() {
    switch (this.args.actionMode) {
      case BUTTON_ACTION_MODE_DELETE:
      case BUTTON_ACTION_MODE_DELETE_TOPIC:
      case BUTTON_ACTION_MODE_SHOW_FLAG_DELETE:
        return "far-trash-alt";

      case BUTTON_ACTION_MODE_RECOVER:
      case BUTTON_ACTION_MODE_RECOVER_TOPIC:
        return "undo";
    }
  }

  get label() {
    switch (this.args.actionMode) {
      case BUTTON_ACTION_MODE_DELETE:
        return "post.controls.delete_action";

      case BUTTON_ACTION_MODE_DELETE_TOPIC:
      case BUTTON_ACTION_MODE_SHOW_FLAG_DELETE:
        return "topic.actions.delete";

      case BUTTON_ACTION_MODE_RECOVER:
        return "post.controls.undelete_action";

      case BUTTON_ACTION_MODE_RECOVER_TOPIC:
        return "topic.actions.recover";
    }
  }

  get title() {
    switch (this.args.actionMode) {
      case BUTTON_ACTION_MODE_DELETE:
        return "post.controls.delete";

      case BUTTON_ACTION_MODE_DELETE_TOPIC:
        return "post.controls.delete_topic";

      case BUTTON_ACTION_MODE_SHOW_FLAG_DELETE:
        return "post.controls.delete_topic_disallowed";

      case BUTTON_ACTION_MODE_RECOVER:
        return "post.controls.undelete";

      case BUTTON_ACTION_MODE_RECOVER_TOPIC:
        return "topic.actions.recover";
    }
  }

  <template>
    {{#if @shouldRender}}
      <DButton
        class={{this.className}}
        ...attributes
        @action={{@action}}
        @icon={{this.icon}}
        @label={{if @showLabel this.label}}
        @title={{this.title}}
      />
    {{/if}}
  </template>
}
