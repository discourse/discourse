import Component from "@glimmer/component";
import { helperContext } from "discourse/lib/helpers";
import { withPluginApi } from "discourse/lib/plugin-api";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import SolvedAcceptAnswerButton from "../components/solved-accept-answer-button";
import SolvedAcceptedAnswers from "../components/solved-accepted-answers";
import SolvedSharedIssueButton from "../components/solved-shared-issue-button";
import SolvedUnacceptAnswerButton from "../components/solved-unaccept-answer-button";
import setAcceptedSolutions from "../lib/set-accepted-solutions";

function topicHasSolvedEnabled(topic) {
  if (!topic) {
    return false;
  }

  const siteSettings = helperContext().siteSettings;

  if (siteSettings.allow_solved_on_all_topics) {
    return true;
  }

  const category = Category.findById(topic.category_id);
  if (category?.custom_fields?.enable_accepted_answers === "true") {
    return true;
  }

  const solvedTags = siteSettings.enable_solved_tags.split("|").filter(Boolean);
  return (topic.tags || []).some((t) => solvedTags.includes(t));
}

function initializeWithApi(api) {
  customizePost(api);
  customizePostMenu(api);
  handleMessages(api);
  customizeNotificationDescriptions(api);

  if (api.addDiscoveryQueryParam) {
    api.addDiscoveryQueryParam("solved", { replace: true, refreshModel: true });
  }

  api.addTrackedTopicProperties(
    "accepted_answers",
    "has_accepted_answer",
    "shared_issue_count",
    "user_created_shared_issue",
    "shared_issue_visible"
  );
}

function customizeNotificationDescriptions(api) {
  api.registerValueTransformer(
    "notifications-tracking-description",
    ({ value, context: { topic, level, prefix } }) => {
      if (prefix !== "topic.notifications" || !topicHasSolvedEnabled(topic)) {
        return value;
      }

      if (level.key === "tracking") {
        return i18n("solved.topic_notifications.tracking.description");
      }

      if (level.key === "watching") {
        return i18n("solved.topic_notifications.watching.description");
      }

      return value;
    }
  );
}

function customizePost(api) {
  api.addTrackedPostProperties(
    "can_accept_answer",
    "accepted_answer",
    "topic_accepted_answer"
  );

  api.renderAfterWrapperOutlet(
    "post-content-cooked-html",
    SolvedAcceptedAnswers
  );
}

function customizePostMenu(api) {
  const siteSettings = helperContext().siteSettings;

  api.registerValueTransformer(
    "post-menu-buttons",
    ({
      value: dag,
      context: {
        post,
        firstButtonKey,
        secondLastHiddenButtonKey,
        lastHiddenButtonKey,
      },
    }) => {
      let solvedButton;

      if (post.accepted_answer) {
        solvedButton = SolvedUnacceptAnswerButton;
      } else if (post.can_accept_answer) {
        solvedButton = SolvedAcceptAnswerButton;
      }

      if (!solvedButton) {
        return;
      }

      const collapse =
        !siteSettings.solved_allow_multiple_solutions &&
        post.topic_accepted_answer &&
        !post.accepted_answer;

      dag.add(
        "solved",
        solvedButton,
        collapse
          ? {
              before: lastHiddenButtonKey,
              after: secondLastHiddenButtonKey,
            }
          : {
              before: [
                "assign", // button added by the assign plugin
                firstButtonKey,
              ],
            }
      );
    }
  );

  api.renderAfterWrapperOutlet(
    "post-content-cooked-html",
    class extends Component {
      static shouldRender(args) {
        return args.post?.post_number === 1;
      }

      <template><SolvedSharedIssueButton @post={{@post}} /></template>
    }
  );
}

function handleMessages(api) {
  const callback = async (controller, message) => {
    const topic = controller.model;

    if (topic) {
      setAcceptedSolutions(topic, message.accepted_answers);
    }
  };

  api.registerCustomPostMessageCallback("accepted_solution", callback);
  api.registerCustomPostMessageCallback("unaccepted_solution", callback);

  api.registerCustomPostMessageCallback(
    "shared_issue",
    (controller, message) => {
      const topic = controller.model;
      if (!topic) {
        return;
      }
      topic.set("shared_issue_count", message.count);
    }
  );
}

export default {
  name: "extend-for-solved-button",
  initialize() {
    withPluginApi(initializeWithApi);

    withPluginApi((api) => {
      api.replaceIcon(
        "notification.solved.accepted_notification",
        "square-check"
      );
      api.replaceIcon(
        "notification.solved.topic_solved_notification",
        "square-check"
      );
    });

    withPluginApi((api) => {
      api.addAdvancedSearchOptions({
        statusOptions: [
          {
            name: i18n("search.advanced.statuses.solved"),
            value: "solved",
          },
          {
            name: i18n("search.advanced.statuses.unsolved"),
            value: "unsolved",
          },
        ],
      });
    });

    withPluginApi((api) => {
      api.addSearchSuggestion("status:solved");
      api.addSearchSuggestion("status:unsolved");
    });
  },
};
