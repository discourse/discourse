import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class AssignButton extends Component {
  static shouldRender(args) {
    return !args.post.firstPost;
  }

  static hidden(args) {
    return args.post.assigned_to_user?.id !== args.state.currentUser.id;
  }

  @service taskActions;

  get icon() {
    return this.isAssigned ? "user-xmark" : "user-plus";
  }

  get isAssigned() {
    return this.args.post.assigned_to_user || this.args.post.assigned_to_group;
  }

  get title() {
    return this.isAssigned
      ? "discourse_assign.unassign_post.title"
      : "discourse_assign.assign_post.title";
  }

  @action
  async acceptAnswer() {
    if (this.isAssigned) {
      const post = this.args.post;

      await this.taskActions.unassign(post.id, "Post");
      delete post.topic.indirectly_assigned_to[post.id];

      // force the components tracking `topic.indirectly_assigned_to` to update
      // eslint-disable-next-line no-self-assign
      post.topic.indirectly_assigned_to = post.topic.indirectly_assigned_to;
    } else {
      this.taskActions.showAssignModal(this.args.post, {
        isAssigned: false,
        targetType: "Post",
      });
    }
  }

  <template>
    <DButton
      class={{if
        this.isAssigned
        "post-action-menu__unassign-post unassign-post"
        "post-action-menu__assign-post assign-post"
      }}
      ...attributes
      @action={{this.acceptAnswer}}
      @icon={{this.icon}}
      @title={{this.title}}
    />
  </template>
}
