import Component from "@glimmer/component";
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

  if (api.addDiscoveryQueryParam) {
    api.addDiscoveryQueryParam("solved", { replace: true, refreshModel: true });
  }
}

function customizePost(api) {
  api.addTrackedPostProperties(
    "can_accept_answer",
    "can_unaccept_answer",
    "accepted_answer",
    "topic_accepted_answer"
  );

  api.renderAfterWrapperOutlet(
    "post-content-cooked-html",
    class extends Component {
      static shouldRender(args) {
        return args.post.post_number === 1 && args.post.topic.accepted_answer;
      }

      <template><SolvedAcceptedAnswer @post={{@outletArgs.post}} /></template>
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

      if (post.can_accept_answer) {
        solvedButton = SolvedAcceptAnswerButton;
      } else if (post.accepted_answer) {
        solvedButton = SolvedUnacceptAnswerButton;
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

export default {
  name: "extend-for-solved-button",
  initialize() {
    withPluginApi("1.34.0", initializeWithApi);

    withPluginApi("0.8.10", (api) => {
      api.replaceIcon(
        "notification.solved.accepted_notification",
        "square-check"
      );
    });

    withPluginApi("0.11.0", (api) => {
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

    withPluginApi("0.11.7", (api) => {
      api.addSearchSuggestion("status:solved");
      api.addSearchSuggestion("status:unsolved");
    });
  },
};
