import { getOwner } from "@ember/application";
import { htmlSafe } from "@ember/template";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";
import EditTopicAssignments from "../components/modal/edit-topic-assignments";

const DEPENDENT_KEYS = [
  "topic.assigned_to_user",
  "topic.assigned_to_group",
  "currentUser.can_assign",
  "topic.assigned_to_user.username",
];

export default {
  id: "reassign",
  dependentKeys: DEPENDENT_KEYS,
  classNames: ["reassign"],

  async action(id) {
    if (!this.currentUser?.can_assign) {
      return;
    }

    const taskActions = getOwner(this).lookup("service:task-actions");
    const modal = getOwner(this).lookup("service:modal");
    const firstPostId = this.topic.postStream.firstPostId;

    switch (id) {
      case "unassign": {
        this.topic.assigned_to_user = null;
        this.topic.assigned_to_group = null;

        await taskActions.unassign(this.topic.id);
        // TODO (glimmer-post-stream) the Glimmer Post Stream does not listen to this event
        this.appEvents.trigger("post-stream:refresh", { id: firstPostId });
        break;
      }
      case "reassign-self": {
        this.topic.assigned_to_user = null;
        this.topic.assigned_to_group = null;

        await taskActions.reassignUserToTopic(this.currentUser, this.topic);
        // TODO (glimmer-post-stream) the Glimmer Post Stream does not listen to this event
        this.appEvents.trigger("post-stream:refresh", { id: firstPostId });
        break;
      }
      case "reassign": {
        await modal.show(EditTopicAssignments, {
          model: {
            topic: this.topic,
          },
          onSuccess: () =>
            // TODO (glimmer-post-stream) the Glimmer Post Stream does not listen to this event
            this.appEvents.trigger("post-stream:refresh", { id: firstPostId }),
        });
        break;
      }
      default: {
        if (id.startsWith("unassign-from-post-")) {
          const postId = extractPostId(id);
          await taskActions.unassign(postId, "Post");

          delete this.topic.indirectly_assigned_to[postId];

          // force the components tracking `topic.indirectly_assigned_to` to update
          // eslint-disable-next-line no-self-assign
          this.topic.indirectly_assigned_to = this.topic.indirectly_assigned_to;
          // TODO (glimmer-post-stream) the Glimmer Post Stream does not listen to this event
          this.appEvents.trigger("post-stream:refresh", { id: firstPostId });
        }
      }
    }
  },

  noneItem() {
    return topicLevelUnassignButton(this.topic.uniqueAssignees());
  },

  content() {
    const content = [];

    if (this.topic.isAssigned()) {
      content.push(
        unassignFromTopicButton(
          this.topic,
          this.siteSettings.prioritize_full_name_in_ux
        )
      );
    }

    if (this.topic.hasAssignedPosts()) {
      content.push(...unassignFromPostButtons(this.topic));
    }

    if (this.topic.isAssigned() && !this.topic.isAssignedTo(this.currentUser)) {
      content.push(reassignToSelfButton());
    }

    content.push(editAssignmentsButton());

    return content;
  },

  displayed() {
    return (
      this.currentUser?.can_assign &&
      !this.site.mobileView &&
      (this.topic.isAssigned() || this.topic.hasAssignedPosts())
    );
  },
};

function avatarHtml(user, size, classes) {
  return renderAvatar(user, {
    imageSize: size,
    extraClasses: classes,
    ignoreTitle: true,
  });
}

function extractPostId(buttonId) {
  // buttonId format is "unassign-from-post-${postId}"
  const start = buttonId.lastIndexOf("-") + 1;
  return buttonId.substring(start);
}

function editAssignmentsButton() {
  const icon = iconHTML("pencil");
  const label = i18n("discourse_assign.topic_level_menu.edit_assignments");
  return {
    id: "reassign",
    name: htmlSafe(label),
    label: htmlSafe(`${icon} ${label}`),
  };
}

function reassignToSelfButton() {
  const icon = iconHTML("user-plus");
  const label = i18n("discourse_assign.topic_level_menu.reassign_topic_to_me");
  return {
    id: "reassign-self",
    name: htmlSafe(label),
    label: htmlSafe(`${icon} ${label}`),
  };
}

function unassignFromTopicButton(topic, prioritize_full_name_in_ux) {
  let username =
    topic.assigned_to_user?.username || topic.assigned_to_group?.name;

  if (topic.assigned_to_user && prioritize_full_name_in_ux) {
    username = topic.assigned_to_user?.name || topic.assigned_to_user?.username;
  }

  const icon = topic.assigned_to_user
    ? avatarHtml(topic.assigned_to_user, "small")
    : iconHTML("user-xmark");
  const label = i18n("discourse_assign.topic_level_menu.unassign_from_topic", {
    username,
  });

  return {
    id: "unassign",
    name: htmlSafe(label),
    label: htmlSafe(`${icon} ${label}`),
  };
}

function unassignFromPostButtons(topic) {
  if (!topic.hasAssignedPosts()) {
    return [];
  }

  const max_buttons = 10;
  return Object.entries(topic.indirectly_assigned_to)
    .slice(0, max_buttons)
    .map(([postId, assignment]) => unassignFromPostButton(postId, assignment));
}

function unassignFromPostButton(postId, assignment) {
  let assignee, icon;
  const assignedToUser = !!assignment.assigned_to.username;
  if (assignedToUser) {
    assignee = assignment.assigned_to.username;
    icon = avatarHtml(assignment.assigned_to, "small");
  } else {
    assignee = assignment.assigned_to.name;
    icon = iconHTML("group-times");
  }

  const label = i18n("discourse_assign.topic_level_menu.unassign_from_post", {
    assignee,
    post_number: assignment.post_number,
  });
  const dataName = i18n(
    "discourse_assign.topic_level_menu.unassign_from_post_help",
    {
      assignee,
      post_number: assignment.post_number,
    }
  );
  return {
    id: `unassign-from-post-${postId}`,
    name: htmlSafe(dataName),
    label: htmlSafe(`${icon} ${label}`),
  };
}

function topicLevelUnassignButton(assignees) {
  const avatars = topicLevelUnassignButtonAvatars(assignees);
  const label = `<span class="unassign-label">${i18n(
    "discourse_assign.topic_level_menu.unassign_with_ellipsis"
  )}</span>`;

  return {
    id: null,
    name: htmlSafe(
      i18n("discourse_assign.topic_level_menu.unassign_with_ellipsis")
    ),
    label: htmlSafe(`${avatars}${label}`),
  };
}

function topicLevelUnassignButtonAvatars(assignees) {
  const users = assignees.filter((a) => a.username);
  let avatars = "";
  if (users.length === 1) {
    avatars = avatarHtml(users[0], "tiny");
  } else if (users.length > 1) {
    avatars =
      avatarHtml(users[0], "tiny", "overlap") + avatarHtml(users[1], "tiny");
  }

  return avatars;
}
