import Component from "@glimmer/component";
import { assignedToGroupPath, assignedToUserPath } from "../lib/url";
import AssignedFirstPost from "./assigned-to-first-post";
import AssignedToPost from "./assigned-to-post";

export default class PostAssignmentsDisplay extends Component {
  static shouldRender(args) {
    return args.post;
  }

  get post() {
    return this.args.outletArgs.post;
  }

  get assignedTo() {
    return this.post.topic?.indirectly_assigned_to?.[this.post.id]?.assigned_to;
  }

  get assignedToUser() {
    return this.assignedTo.username ? this.assignedTo : null;
  }

  get assignedToGroup() {
    return !this.assignedToUser && this.assignedTo.name
      ? this.assignedTo
      : null;
  }

  get assignedHref() {
    return this.assignedToUser
      ? assignedToUserPath(this.assignedToUser)
      : assignedToGroupPath(this.assignedToGroup);
  }

  <template>
    {{#if this.post.firstPost}}
      <AssignedFirstPost @post={{this.post}} />
    {{else if this.assignedTo}}
      <p class="assigned-to">
        <AssignedToPost
          @assignedToUser={{this.assignedToUser}}
          @assignedToGroup={{this.assignedToGroup}}
          @href={{this.assignedHref}}
          @post={{this.post}}
        />
      </p>
    {{/if}}
  </template>
}
