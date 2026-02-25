import Component from "@glimmer/component";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import SolvedAcceptAnswerButton from "../components/solved-accept-answer-button";
import SolvedAcceptedAnswer from "../components/solved-accepted-answer";
import SolvedUnacceptAnswerButton from "../components/solved-unaccept-answer-button";
import setAcceptedSolution from "../lib/set-accepted-solution";

function initializeWithApi(api) {
  customizePost(api);
  customizePostMenu(api);
  handleMessages(api);

  if (api.addDiscoveryQueryParam) {
    api.addDiscoveryQueryParam("solved", { replace: true, refreshModel: true });
  }

  api.addTrackedTopicProperties("accepted_answer", "has_accepted_answer");
}

function customizePost(api) {
  api.addTrackedPostProperties(
    "can_accept_answer",
    "accepted_answer",
    "topic_accepted_answer"
  );

  api.renderAfterWrapperOutlet(
    "post-content-cooked-html",
    class extends Component {
      static shouldRender(args) {
        return (
          args.post?.post_number === 1 && args.post?.topic?.accepted_answer
        );
      }

      <template>
        <SolvedAcceptedAnswer
          @post={{@post}}
          @decoratorState={{@decoratorState}}
        />
      </template>
    }
  );
}

function customizePostMenu(api) {
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

      solvedButton &&
        dag.add(
          "solved",
          solvedButton,
          post.topic_accepted_answer && !post.accepted_answer
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
}

function handleMessages(api) {
  const callback = async (controller, message) => {
    const topic = controller.model;

    if (topic) {
      setAcceptedSolution(topic, message.accepted_answer);
    }
  };

  api.registerCustomPostMessageCallback("accepted_solution", callback);
  api.registerCustomPostMessageCallback("unaccepted_solution", callback);
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
