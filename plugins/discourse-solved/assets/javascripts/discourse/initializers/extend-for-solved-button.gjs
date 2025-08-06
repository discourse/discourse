import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { withPluginApi } from "discourse/lib/plugin-api";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { i18n } from "discourse-i18n";
import SolvedAcceptAnswerButton from "../components/solved-accept-answer-button";
import SolvedAcceptedAnswer from "../components/solved-accepted-answer";
import SolvedUnacceptAnswerButton from "../components/solved-unaccept-answer-button";

function initializeWithApi(api) {
  customizePost(api);
  customizePostMenu(api);
  handleMessages(api);

  if (api.addDiscoveryQueryParam) {
    api.addDiscoveryQueryParam("solved", { replace: true, refreshModel: true });
  }

  api.modifyClass(
    "model:topic",
    (Superclass) =>
      class extends Superclass {
        @tracked accepted_answer;
        @tracked has_accepted_answer;

        setAcceptedSolution(acceptedAnswer) {
          this.postStream?.posts?.forEach((post) => {
            if (!acceptedAnswer) {
              post.setProperties({
                accepted_answer: false,
                topic_accepted_answer: false,
              });
            } else if (post.post_number > 1) {
              post.setProperties(
                acceptedAnswer.post_number === post.post_number
                  ? {
                      accepted_answer: true,
                      topic_accepted_answer: true,
                    }
                  : {
                      accepted_answer: false,
                      topic_accepted_answer: true,
                    }
              );
            }
          });

          this.accepted_answer = acceptedAnswer;
          this.has_accepted_answer = !!acceptedAnswer;
        }
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

  withSilencedDeprecations("discourse.post-stream-widget-overrides", () =>
    customizeWidgetPost(api)
  );
}

function customizeWidgetPost(api) {
  api.decorateWidget("post-contents:after-cooked", (helper) => {
    let post = helper.getModel();

    if (helper.attrs.post_number === 1 && post?.topic?.accepted_answer) {
      return new RenderGlimmer(
        helper.widget,
        "div",
        <template><SolvedAcceptedAnswer @post={{@data.post}} /></template>,
        { post }
      );
    }
  });
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
      topic.setAcceptedSolution(message.accepted_answer);
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
