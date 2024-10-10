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
  static shouldRender(args) {
    return !!PostMenuDeleteButton.modeFor(args.post);
  }

  static modeFor(post) {
    if (post.canRecoverTopic) {
      return BUTTON_ACTION_MODE_RECOVER_TOPIC;
    } else if (post.canDeleteTopic) {
      return BUTTON_ACTION_MODE_DELETE_TOPIC;
    } else if (post.canRecover) {
      return BUTTON_ACTION_MODE_RECOVER;
    } else if (post.canDelete) {
      return BUTTON_ACTION_MODE_DELETE;
    } else if (post.showFlagDelete) {
      return BUTTON_ACTION_MODE_SHOW_FLAG_DELETE;
    } else if (post.isRecovering) {
      return BUTTON_ACTION_MODE_RECOVERING;
    } else if (post.isRecoveringTopic) {
      return BUTTON_ACTION_MODE_RECOVERING_TOPIC;
    }
  }

  get className() {
    switch (this.#activeMode) {
      case BUTTON_ACTION_MODE_RECOVER:
      case BUTTON_ACTION_MODE_RECOVER_TOPIC:
      case BUTTON_ACTION_MODE_RECOVERING:
      case BUTTON_ACTION_MODE_RECOVERING_TOPIC:
        return "post-action-menu__recover recover";
      default:
        return "post-action-menu__delete delete";
    }
  }

  get icon() {
    switch (this.#activeMode) {
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
    switch (this.#activeMode) {
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
    switch (this.#activeMode) {
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

  get activeAction() {
    if (this.args.post.canRecoverTopic) {
      return this.args.buttonActions.recoverPost;
    } else if (this.args.post.canDeleteTopic) {
      return this.args.buttonActions.deletePost;
    } else if (this.args.post.canRecover) {
      return this.args.buttonActions.recoverPost;
    } else if (this.args.post.canDelete) {
      return this.args.buttonActions.deletePost;
    } else if (this.args.post.showFlagDelete) {
      return this.args.buttonActions.showDeleteTopicModal;
    }
  }

  get disabled() {
    return !this.activeAction;
  }

  get #activeMode() {
    return this.constructor.modeFor(this.args.post);
  }

  <template>
    <DButton
      class={{this.className}}
      ...attributes
      disabled={{this.disabled}}
      @action={{this.activeAction}}
      @icon={{this.icon}}
      @label={{if @showLabel this.label}}
      @title={{this.title}}
    />
  </template>
}
