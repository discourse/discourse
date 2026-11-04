import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { bind } from "discourse/lib/decorators";
import { escapeExpression } from "discourse/lib/utilities";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  assignedToGroupPath,
  assignedToPostPath,
  assignedToUserPath,
} from "../lib/url.js";

export default class AssignedToFirstPost extends Component {
  @service siteSettings;

  get assignedToUser() {
    return this.args.post?.topic?.assigned_to_user;
  }

  get topicAssignments() {
    const assignments = this.args.post?.topic?.topic_assignments;
    if (
      !this.siteSettings.assign_allow_multiple_topic_assignees &&
      !(assignments?.length > 1)
    ) {
      return;
    }
    return assignments?.map((assignment) => ({
      ...assignment,
      path:
        assignment.assigned_to_type === "User"
          ? assignedToUserPath(assignment.assigned_to)
          : assignedToGroupPath(assignment.assigned_to),
    }));
  }

  get hasNotes() {
    return this.topicAssignments?.some((assignment) => assignment.note);
  }

  get assignedToGroup() {
    return this.args.post?.topic?.assigned_to_group;
  }

  get icon() {
    return this.assignedToUser ||
      this.topicAssignments?.some(
        (assignment) => assignment.assigned_to_type === "User"
      )
      ? "user-plus"
      : "group-plus";
  }

  get indirectlyAssignedTo() {
    return this.args.post?.topic?.indirectly_assigned_to;
  }

  get indirectAssignments() {
    if (!this.indirectlyAssignedTo) {
      return null;
    }

    return Object.keys(this.indirectlyAssignedTo).map((postId) => {
      return {
        postId,
        assignee: this.indirectlyAssignedTo[postId].assigned_to,
        postNumber: this.indirectlyAssignedTo[postId].post_number,
        url: assignedToPostPath(postId),
      };
    });
  }

  get hasIndirectAssignments() {
    return this.indirectlyAssignedTo
      ? Object.keys(this.indirectlyAssignedTo).length > 0
      : false;
  }

  get isAssigned() {
    return !!(
      this.topicAssignments?.length ||
      this.assignedToUser ||
      this.assignedToGroup ||
      this.hasIndirectAssignments
    );
  }

  get hasOnlyIndirectAssignments() {
    return !this.assignedToUser && !this.assignedToGroup;
  }

  @bind
  prioritizedAssigneeName(assignee) {
    // if this code is ever replaced to use `prioritize_username_in_ux`, remove this function and use the helper
    // userPrioritizedName instead
    return this.siteSettings.prioritize_full_name_in_ux || !assignee.username
      ? assignee.name || assignee.username
      : assignee.username;
  }

  @bind
  escapedPrioritizedAssigneeName(assignee) {
    return escapeExpression(this.prioritizedAssigneeName(assignee));
  }

  <template>
    {{#if this.isAssigned}}
      <p class="assigned-to">
        {{#unless this.topicAssignments.length}}{{dIcon this.icon}}{{/unless}}
        {{#if this.topicAssignments.length}}
          <span class="assigned-to__label">
            {{dIcon this.icon}}
            {{i18n "discourse_assign.assigned_topic_label"}}
          </span>
          <span
            class={{if
              this.hasNotes
              "assigned-to__assignments --with-notes"
              "assigned-to__assignments"
            }}
          >
            {{#each this.topicAssignments key="id" as |assignment|}}
              <span class="assigned-to__assignment">
                <a class="assigned-to__assignee" href={{assignment.path}}>
                  {{#if (eq assignment.assigned_to_type "User")}}
                    {{dAvatar assignment.assigned_to imageSize="small"}}
                    <span>@{{assignment.assigned_to.username}}</span>
                  {{else}}
                    {{dIcon "group-plus"}}
                    <span>@{{assignment.assigned_to.name}}</span>
                  {{/if}}
                </a>
                {{#if assignment.status}}<span
                    class="assigned-to__status"
                  >{{assignment.status}}</span>{{/if}}
                {{#if assignment.note}}<span
                    class="assigned-to__note"
                  >{{assignment.note}}</span>{{/if}}
              </span>
            {{/each}}
          </span>
        {{else if this.assignedToUser}}
          <span class="assignee">
            <span class="assigned-to--user">
              {{trustHTML
                (i18n
                  "discourse_assign.assigned_topic_to"
                  username=(this.escapedPrioritizedAssigneeName
                    this.assignedToUser
                  )
                  path=(assignedToUserPath this.assignedToUser)
                )
              }}
            </span>
          </span>
        {{/if}}

        {{#if (and (not this.topicAssignments.length) this.assignedToGroup)}}
          <span class="assignee">
            <span class="assigned-to--group">
              {{trustHTML
                (i18n
                  "discourse_assign.assigned_topic_to"
                  username=(this.escapedPrioritizedAssigneeName
                    this.assignedToGroup
                  )
                  path=(assignedToGroupPath this.assignedToGroup)
                )
              }}
            </span>
          </span>
        {{/if}}

        {{#if this.hasOnlyIndirectAssignments}}
          <span class="assign-text">
            {{i18n "discourse_assign.assigned"}}
          </span>
        {{/if}}
        {{#if this.hasIndirectAssignments}}
          {{#each
            this.indirectAssignments key="postId"
            as |indirectAssignment|
          }}
            <span class="assignee">
              <a class="assigned-indirectly" href={{indirectAssignment.url}}>
                {{i18n
                  "discourse_assign.assign_post_to_multiple"
                  post_number=indirectAssignment.postNumber
                  username=(this.prioritizedAssigneeName
                    indirectAssignment.assignee
                  )
                }}
              </a>
            </span>
          {{/each}}
        {{/if}}
      </p>
    {{/if}}
  </template>
}
