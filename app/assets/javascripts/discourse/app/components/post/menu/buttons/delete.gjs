import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export const BUTTON_ACTION_MODE_DELETE = "delete";
export const BUTTON_ACTION_MODE_DELETE_TOPIC = "delete-topic";
export const BUTTON_ACTION_MODE_SHOW_FLAG_DELETE = "show-flag-delete";
export const BUTTON_ACTION_MODE_RECOVER = "recover";
export const BUTTON_ACTION_MODE_RECOVER_TOPIC = "recover-topic";
export const BUTTON_ACTION_MODE_RECOVERING = "recovering";
export const BUTTON_ACTION_MODE_RECOVERING_TOPIC = "recovering-topic";

export default class PostMenuDeleteButton extends Component {
  static shouldRender(post) {
    return post.can_edit;
  }

  get className() {
    switch (this.args.actionMode) {
      case BUTTON_ACTION_MODE_RECOVER:
      case BUTTON_ACTION_MODE_RECOVER_TOPIC:
      case BUTTON_ACTION_MODE_RECOVERING:
      case BUTTON_ACTION_MODE_RECOVERING_TOPIC:
        return "recover";
      default:
        return "delete";
    }
  }

  get icon() {
    switch (this.args.actionMode) {
      case BUTTON_ACTION_MODE_RECOVER:
      case BUTTON_ACTION_MODE_RECOVER_TOPIC:
      case BUTTON_ACTION_MODE_RECOVERING:
      case BUTTON_ACTION_MODE_RECOVERING_TOPIC:
        return "undo";

      default:
        return "far-trash-alt";
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
      case BUTTON_ACTION_MODE_RECOVERING:
        return "post.controls.undelete_action";

      case BUTTON_ACTION_MODE_RECOVER_TOPIC:
      case BUTTON_ACTION_MODE_RECOVERING_TOPIC:
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
      case BUTTON_ACTION_MODE_RECOVERING:
        return "post.controls.undelete";

      case BUTTON_ACTION_MODE_RECOVER_TOPIC:
      case BUTTON_ACTION_MODE_RECOVERING_TOPIC:
        return "topic.actions.recover";
    }
  }

  get disabled() {
    return !this.args.action;
  }

  <template>
    {{#if @shouldRender}}
      <DButton
        class={{this.className}}
        ...attributes
        disabled={{this.disabled}}
        @action={{@action}}
        @icon={{this.icon}}
        @label={{if @showLabel this.label}}
        @title={{this.title}}
      />
    {{/if}}
  </template>
}
