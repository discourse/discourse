import { getOwner } from "@ember/owner";
import { htmlSafe } from "@ember/template";
import { renderAvatar } from "discourse/helpers/user-avatar";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { iconHTML } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import { registerTopicFooterDropdown } from "discourse/lib/register-topic-footer-dropdown";
import { applyValueTransformer } from "discourse/lib/transformer";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import AssignButton from "../components/assign-button";
import BulkActionsAssignUser from "../components/bulk-actions/bulk-assign-user";
import EditTopicAssignments from "../components/modal/edit-topic-assignments";
import PostAssignmentsDisplay from "../components/post-assignments-display";
import TopicLevelAssignMenu from "../components/topic-level-assign-menu";
import {
  assignedToGroupPath,
  assignedToPostPath,
  assignedToUserPath,
} from "../lib/url";
import { extendTopicModel } from "../models/topic";

const DEPENDENT_KEYS = [
  "topic.assigned_to_user",
  "topic.assigned_to_group",
  "currentUser.can_assign",
  "topic.assigned_to_user.username",
  "topic.assigned_to_user.name",
];

function defaultTitle(topic) {
  const username =
    topic.assigned_to_user?.username || topic.assigned_to_group?.name;

  if (username) {
    return i18n("discourse_assign.unassign.help", { username });
  } else {
    return i18n("discourse_assign.assign.help");
  }
}

function registerTopicFooterButtons(api) {
  registerTopicFooterDropdown(TopicLevelAssignMenu);

  // api.registerTopicFooterButton({
  //   id: "assign",
  //   icon() {
  //     return this.topic.isAssigned()
  //       ? this.site.mobileView
  //         ? "user-xmark"
  //         : null
  //       : "user-plus";
  //   },
  //   priority: 250,
  //   translatedTitle() {
  //     return defaultTitle(this.topic);
  //   },
  //   translatedAriaLabel() {
  //     return defaultTitle(this.topic);
  //   },
  //   translatedLabel() {
  //     return i18n("discourse_assign.assign.title");
  //   },
  //   async action() {
  //     if (!this.currentUser?.can_assign) {
  //       return;
  //     }

  //     const taskActions = getOwner(this).lookup("service:task-actions");
  //     const modal = getOwner(this).lookup("service:modal");

  //     if (this.topic.isAssigned()) {
  //       this.topic.assigned_to_user = null;
  //       this.topic.assigned_to_group = null;

  //       await taskActions.unassign(this.topic.id, "Topic");
  //     } else {
  //       await modal.show(EditTopicAssignments, {
  //         model: {
  //           topic: this.topic,
  //         },
  //       });
  //     }
  //   },
  //   dropdown() {
  //     return this.site.mobileView;
  //   },
  //   classNames: ["assign"],
  //   dependentKeys: DEPENDENT_KEYS,
  //   displayed() {
  //     return (
  //       this.currentUser?.can_assign &&
  //       !this.topic.isAssigned() &&
  //       !this.topic.hasAssignedPosts()
  //     );
  //   },
  // });

  api.registerTopicFooterButton({
    id: "unassign-mobile-header",
    translatedTitle() {
      return defaultTitle(this.topic);
    },
    translatedAriaLabel() {
      return defaultTitle(this.topic);
    },
    translatedLabel() {
      const user = this.topic.assigned_to_user;
      const group = this.topic.assigned_to_group;
      const label = i18n("discourse_assign.assigned_to");

      if (user) {
        return htmlSafe(
          `<span class="unassign-label"><span class="text">${label}&nbsp;</span><span class="username">${
            user.username
          }</span></span>&nbsp;${renderAvatar(user, {
            imageSize: "small",
            ignoreTitle: true,
          })}`
        );
      } else if (group) {
        return htmlSafe(
          `<span class="unassign-label">${label}</span> @${group.name}`
        );
      }
    },
    dropdown() {
      return this.currentUser?.can_assign && this.topic.isAssigned();
    },
    classNames: ["assign"],
    dependentKeys: DEPENDENT_KEYS,
    displayed() {
      // only display the button in the mobile view
      return this.currentUser?.can_assign && this.site.mobileView;
    },
  });

  api.registerTopicFooterButton({
    id: "unassign-mobile",
    icon() {
      return "user-xmark";
    },
    translatedTitle() {
      return defaultTitle(this.topic);
    },
    translatedAriaLabel() {
      return defaultTitle(this.topic);
    },
    translatedLabel() {
      const label = i18n("discourse_assign.unassign.title");

      return htmlSafe(
        `<span class="unassign-label"><span class="text">${label}</span></span>`
      );
    },
    action() {
      if (!this.currentUser?.can_assign) {
        return;
      }

      const taskActions = getOwner(this).lookup("service:task-actions");

      this.topic.assigned_to_user = null;
      this.topic.assigned_to_group = null;
      taskActions.unassign(this.topic.id);
    },
    dropdown() {
      return this.currentUser?.can_assign && this.topic.isAssigned();
    },
    classNames: ["assign"],
    dependentKeys: DEPENDENT_KEYS,
    displayed() {
      // only display the button in the mobile view
      return (
        this.currentUser?.can_assign &&
        this.site.mobileView &&
        this.topic.isAssigned()
      );
    },
  });

  api.registerTopicFooterButton({
    id: "reassign-self-mobile",
    icon() {
      return "user-plus";
    },
    translatedTitle() {
      return i18n("discourse_assign.reassign.to_self_help");
    },
    translatedAriaLabel() {
      return i18n("discourse_assign.reassign.to_self_help");
    },
    translatedLabel() {
      const label = i18n("discourse_assign.reassign.to_self");

      return htmlSafe(
        `<span class="unassign-label"><span class="text">${label}</span></span>`
      );
    },
    async action() {
      if (!this.currentUser?.can_assign) {
        return;
      }

      const taskActions = getOwner(this).lookup("service:task-actions");

      this.topic.assigned_to_user = null;
      this.topic.assigned_to_group = null;

      await taskActions.reassignUserToTopic(this.currentUser, this.topic);
    },
    dropdown() {
      return this.currentUser?.can_assign && this.topic.isAssigned();
    },
    classNames: ["assign"],
    dependentKeys: DEPENDENT_KEYS,
    displayed() {
      return (
        // only display the button in the mobile view
        this.site.mobileView &&
        this.currentUser?.can_assign &&
        this.topic.isAssigned() &&
        this.topic.assigned_to_user?.username !== this.currentUser.username
      );
    },
  });

  api.registerTopicFooterButton({
    id: "reassign-mobile",
    icon() {
      return "group-plus";
    },
    translatedTitle() {
      return i18n("discourse_assign.reassign.help");
    },
    translatedAriaLabel() {
      return i18n("discourse_assign.reassign.help");
    },
    translatedLabel() {
      const label = i18n("discourse_assign.reassign.title_w_ellipsis");

      return htmlSafe(
        `<span class="unassign-label"><span class="text">${label}</span></span>`
      );
    },
    async action() {
      if (!this.currentUser?.can_assign) {
        return;
      }

      const taskActions = getOwner(this).lookup("service:task-actions");

      await taskActions.showAssignModal(this.topic, {
        targetType: "Topic",
        isAssigned: this.topic.isAssigned(),
      });
    },
    dropdown() {
      return this.currentUser?.can_assign && this.topic.isAssigned();
    },
    classNames: ["assign"],
    dependentKeys: DEPENDENT_KEYS,
    displayed() {
      // only display the button in the mobile view
      return this.currentUser?.can_assign && this.site.mobileView;
    },
  });
}

function initialize(api) {
  const siteSettings = api.container.lookup("service:site-settings");
  const currentUser = api.getCurrentUser();

  if (siteSettings.assigns_public || currentUser?.can_assign) {
    api.addNavigationBarItem({
      name: "unassigned",
      customFilter: (category) => {
        return category?.custom_fields?.enable_unassigned_filter === "true";
      },
      customHref: (category) => {
        if (category) {
          return getURL(category.url) + "/l/latest?status=open&assigned=nobody";
        }
      },
      forceActive: (category, args) => {
        const queryParams = args.currentRouteQueryParams;

        return (
          queryParams &&
          Object.keys(queryParams).length === 2 &&
          queryParams["assigned"] === "nobody" &&
          queryParams["status"] === "open"
        );
      },
      before: "top",
    });

    if (api.getCurrentUser()?.can_assign) {
      customizePostMenu(api);
    }
  }

  api.addAdvancedSearchOptions(
    api.getCurrentUser()?.can_assign
      ? {
          inOptionsForUsers: [
            {
              name: i18n("search.advanced.in.assigned"),
              value: "assigned",
            },
            {
              name: i18n("search.advanced.in.unassigned"),
              value: "unassigned",
            },
          ],
        }
      : {}
  );

  api.modifyClass(
    "model:bookmark",
    (Superclass) =>
      class extends Superclass {
        @discourseComputed("assigned_to_user")
        assignedToUserPath(assignedToUser) {
          return assignedToUserPath(assignedToUser);
        }

        @discourseComputed("assigned_to_group")
        assignedToGroupPath(assignedToGroup) {
          return assignedToGroupPath(assignedToGroup);
        }
      }
  );

  api.modifyClass(
    "component:topic-notifications-button",
    (Superclass) =>
      class extends Superclass {
        get reasonText() {
          if (
            this.currentUser.never_auto_track_topics &&
            this.args.topic.get("assigned_to_user.username") ===
              this.currentUser.username
          ) {
            return i18n("notification_reason.user");
          }

          return super.reasonText;
        }
      }
  );

  api.addDiscoveryQueryParam("assigned", { replace: true, refreshModel: true });

  api.addTagsHtmlCallback((topic, params = {}) => {
    const [assignedToUser, assignedToGroup, topicNote] = Object.values(
      topic.getProperties(
        "assigned_to_user",
        "assigned_to_group",
        "assignment_note",
        "assignment_status"
      )
    );

    const topicAssignee = {
      assignee: assignedToUser || assignedToGroup,
      note: topicNote,
    };

    let assignedToIndirectly;
    if (topic.indirectly_assigned_to) {
      assignedToIndirectly = Object.entries(topic.indirectly_assigned_to).map(
        ([key, value]) => {
          value.assigned_to.assignedToPostId = key;
          return value;
        }
      );
    } else {
      assignedToIndirectly = [];
    }
    const assignedTo = []
      .concat(
        topicAssignee,
        assignedToIndirectly.map((assigned) => ({
          assignee: assigned.assigned_to,
          note: assigned.assignment_note,
        }))
      )
      .filter(({ assignee }) => assignee)
      .flat();

    if (!assignedTo) {
      return "";
    }

    const createTagHtml = ({ assignee, note }) => {
      let assignedPath;
      if (assignee.assignedToPostId) {
        assignedPath = assignedToPostPath(assignee.assignedToPostId);
      } else if (assignee.username) {
        assignedPath = assignedToUserPath(assignee);
      } else {
        assignedPath = assignedToGroupPath(assignee);
      }

      const icon = iconHTML(assignee.username ? "user-plus" : "group-plus");
      const showNameInUx = siteSettings.prioritize_full_name_in_ux;
      const name =
        showNameInUx || !assignee.username
          ? assignee.name || assignee.username
          : assignee.username;

      const tagName = params.tagName || "a";
      const href =
        tagName === "a" ? `href="${assignedPath}" data-auto-route="true"` : "";

      return `<${tagName} class="assigned-to discourse-tag simple" ${href}>${icon}<span title="${escapeExpression(
        note
      )}">${name}</span></${tagName}>`;
    };

    // is there's one assignment just return the tag
    if (assignedTo.length === 1) {
      return createTagHtml(assignedTo[0]);
    }

    // join multiple assignments with a separator
    let result = "";
    assignedTo.forEach((assignment, index) => {
      result += createTagHtml(assignment);

      // add separator if not the last tag
      if (index < assignedTo.length - 1) {
        const separator = applyValueTransformer("tag-separator", ",", {
          topic,
          index,
        });
        result += `<span class="discourse-tags__tag-separator">${separator}</span>`;
      }
    });

    return result;
  });

  api.modifyClass(
    "model:group",
    (Superclass) =>
      class extends Superclass {
        asJSON() {
          return Object.assign({}, super.asJSON(...arguments), {
            assignable_level: this.assignable_level,
          });
        }
      }
  );

  api.modifyClass(
    "controller:topic",
    (Superclass) =>
      class extends Superclass {
        subscribe() {
          super.subscribe(...arguments);

          this.messageBus.subscribe("/staff/topic-assignment", (data) => {
            const topic = this.model;
            const topicId = topic.id;

            if (data.topic_id === topicId) {
              let post;
              if (data.post_id) {
                post = topic.postStream.posts.find(
                  (p) => p.id === data.post_id
                );
              }
              const target = post || topic;

              target.assignment_note = data.assignment_note;
              target.assignment_status = data.assignment_status;
              if (data.assigned_type === "User") {
                target.assigned_to_user_id =
                  data.type === "assigned" ? data.assigned_to.id : null;
                target.assigned_to_user = data.assigned_to;
              }
              if (data.assigned_type === "Group") {
                target.assigned_to_group_id =
                  data.type === "assigned" ? data.assigned_to.id : null;
                target.assigned_to_group = data.assigned_to;
              }

              if (data.post_id) {
                if (data.type === "assigned") {
                  topic.indirectly_assigned_to[data.post_id].assigned_to =
                    data.assigned_to;
                } else if (data.type === "unassigned") {
                  delete topic.indirectly_assigned_to[data.post_id];
                }
              }
            }
            // force the components tracking `topic.indirectly_assigned_to` to update
            // eslint-disable-next-line no-self-assign
            topic.indirectly_assigned_to = topic.indirectly_assigned_to;

            this.appEvents.trigger("header:update-topic", topic);
          });
        }

        unsubscribe() {
          super.unsubscribe(...arguments);

          if (!this.model?.id) {
            return;
          }

          this.messageBus.unsubscribe("/staff/topic-assignment");
        }
      }
  );

  customizePost(api, siteSettings);

  api.replaceIcon("notification.assigned", "user-plus");

  api.replaceIcon(
    "notification.discourse_assign.assign_group_notification",
    "group-plus"
  );

  api.addSaveableCustomFields("notifications");

  api.addKeyboardShortcut("g a", "", { path: "/my/activity/assigned" });
}

function customizePost(api, siteSettings) {
  api.addTrackedPostProperties(
    "assigned_to_group",
    "assigned_to_group_id",
    "assigned_to_user",
    "assigned_to_user_id",
    "assignment_note",
    "assignment_status"
  );

  api.modifyClass(
    "model:post",
    (Superclass) =>
      class extends Superclass {
        get can_edit() {
          return isAssignSmallAction(this.action_code) ? true : super.can_edit;
        }

        // overriding tracked properties requires overriding both the getter and the setter.
        // otherwise the superclass will throw an error when the application sets the field value
        set can_edit(value) {
          super.can_edit = value;
        }

        get isSmallAction() {
          return isAssignSmallAction(this.action_code)
            ? true
            : super.isSmallAction;
        }
      }
  );

  api.renderAfterWrapperOutlet(
    "post-content-cooked-html",
    PostAssignmentsDisplay
  );

  api.addPostSmallActionClassesCallback((post) => {
    const actionCode = post.action_code;

    if (actionCode.includes("assigned") && !siteSettings.assigns_public) {
      return ["private-assign"];
    }
  });

  api.addPostSmallActionIcon("assigned", "user-plus");
  api.addPostSmallActionIcon("assigned_to_post", "user-plus");
  api.addPostSmallActionIcon("assigned_group", "group-plus");
  api.addPostSmallActionIcon("assigned_group_to_post", "group-plus");
  api.addPostSmallActionIcon("unassigned", "user-xmark");
  api.addPostSmallActionIcon("unassigned_group", "group-times");
  api.addPostSmallActionIcon("unassigned_from_post", "user-xmark");
  api.addPostSmallActionIcon("unassigned_group_from_post", "group-times");
  api.addPostSmallActionIcon("reassigned", "user-plus");
  api.addPostSmallActionIcon("reassigned_group", "group-plus");
}

function isAssignSmallAction(actionCode) {
  return [
    "assigned",
    "unassigned",
    "reassigned",
    "assigned_group",
    "unassigned_group",
    "reassigned_group",
    "assigned_to_post",
    "assigned_group_to_post",
    "unassigned_from_post",
    "unassigned_group_from_post",
    "details_change",
    "note_change",
    "status_change",
  ].includes(actionCode);
}

function customizePostMenu(api) {
  api.registerValueTransformer(
    "post-menu-buttons",
    ({
      value: dag,
      context: {
        post,
        state,
        firstButtonKey,
        lastHiddenButtonKey,
        secondLastHiddenButtonKey,
      },
    }) => {
      dag.add(
        "assign",
        AssignButton,
        post.assigned_to_user?.id === state.currentUser.id
          ? {
              before: firstButtonKey,
            }
          : {
              before: lastHiddenButtonKey,
              after: secondLastHiddenButtonKey,
            }
      );
    }
  );
}

const REGEXP_USERNAME_PREFIX = /^(assigned:)/gi;

export default {
  name: "extend-for-assign",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.assign_enabled) {
      return;
    }

    withPluginApi((api) => {
      const currentUser = container.lookup("service:current-user");
      if (currentUser?.can_assign) {
        api.modifyClass(
          "component:search-advanced-options",
          (Superclass) =>
            class extends Superclass {
              updateSearchTermForAssignedUsername() {
                const match = this.filterBlocks(REGEXP_USERNAME_PREFIX);
                const userFilter = this.searchedTerms?.assigned;
                let searchTerm = this.searchTerm || "";
                let keyword = "assigned";

                if (userFilter?.length !== 0) {
                  if (match.length !== 0) {
                    searchTerm = searchTerm.replace(
                      match[0],
                      `${keyword}:${userFilter}`
                    );
                  } else {
                    searchTerm += ` ${keyword}:${userFilter}`;
                  }

                  this._updateSearchTerm(searchTerm);
                } else if (match.length !== 0) {
                  searchTerm = searchTerm.replace(match[0], "");
                  this._updateSearchTerm(searchTerm);
                }
              }
            }
        );
      }

      extendTopicModel(api);
      initialize(api);
      registerTopicFooterButtons(api);

      api.addSearchSuggestion("in:assigned");
      api.addSearchSuggestion("in:unassigned");

      api.addGroupPostSmallActionCode("assigned_group");
      api.addGroupPostSmallActionCode("reassigned_group");
      api.addGroupPostSmallActionCode("unassigned_group");
      api.addGroupPostSmallActionCode("assigned_group_to_post");
      api.addGroupPostSmallActionCode("unassigned_group_from_post");

      api.addUserSearchOption("assignableGroups");

      api.addSaveableUserOption("notification_level_when_assigned", {
        page: "tracking",
      });

      api.addBulkActionButton({
        id: "assign-topics",
        label: "topics.bulk.assign",
        icon: "user-plus",
        class: "btn-default assign-topics",
        action({ setComponent }) {
          setComponent(BulkActionsAssignUser);
        },
        actionType: "setComponent",
      });

      api.addBulkActionButton({
        id: "unassign-topics",
        label: "topics.bulk.unassign",
        icon: "user-xmark",
        class: "btn-default unassign-topics",
        action({ performAndRefresh }) {
          performAndRefresh({ type: "unassign" });
        },
        actionType: "performAndRefresh",
      });
    });
  },
};
