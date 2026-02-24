import Component from "@glimmer/component";
import { apiInitializer } from "discourse/lib/api";
import AiTopicGist from "../components/ai-topic-gist";
import BulkActionsAiRegenSummaries from "../components/bulk-actions/ai-regen-summaries";
import AiRegenSummariesModal from "../components/modal/ai-regen-summaries-modal";

export default apiInitializer((api) => {
  const settings = api.container.lookup("service:site-settings");
  const currentUser = api.getCurrentUser();
  const MAX_ALLOWED_REGEN = 30;

  api.addBulkActionButton({
    label: "discourse_ai.summarization.topic.regenerate_ai_summaries",
    icon: "arrows-rotate",
    class: "btn-default",
    visible: ({ topics, siteSettings, currentUser: user }) => {
      if (topics?.length > MAX_ALLOWED_REGEN) {
        return false;
      }
      return (
        siteSettings.discourse_ai_enabled &&
        siteSettings.ai_summarization_enabled &&
        user.staff
      );
    },
    action({ setComponent, topics, afterBulkAction }) {
      setComponent(BulkActionsAiRegenSummaries, { topics, afterBulkAction });
    },
    actionType: "setComponent",
  });

  if (settings.discourse_ai_enabled && settings.ai_summarization_enabled) {
    const OUTLETS = {
      mobile: "topic-list-main-link-bottom",
      desktop: "topic-list-topic-cell-link-bottom-line__before",
    };

    function isGistEnabledRoute(routeName) {
      if (routeName?.startsWith("discovery.")) {
        return true;
      }

      if (routeName?.startsWith("filter")) {
        return true;
      }

      if (routeName?.startsWith("userPrivateMessages")) {
        return true;
      }

      if (routeName?.startsWith("topic.")) {
        return true;
      }

      if (routeName?.startsWith("tag.")) {
        return true;
      }

      if (routeName?.startsWith("tags.")) {
        return true;
      }

      return false;
    }

    function renderGistInOutlet(outletName, shouldRenderFn) {
      api.renderInOutlet(
        outletName,
        class extends Component {
          static shouldRender(args, context, owner) {
            if (!shouldRenderFn(context)) {
              return false;
            }

            const router = owner.lookup("service:router");
            return isGistEnabledRoute(router.currentRouteName);
          }

          <template><AiTopicGist @topic={{@topic}} /></template>
        }
      );
    }

    renderGistInOutlet(OUTLETS.mobile, (context) => context.site.mobileView);
    renderGistInOutlet(OUTLETS.desktop, (context) => context.site.desktopView);

    api.addTopicAdminMenuButton((topic) => {
      if (!currentUser?.staff) {
        return;
      }

      const modal = api.container.lookup("service:modal");

      return {
        action: () => {
          modal.show(AiRegenSummariesModal, {
            model: { topic },
          });
        },
        icon: "arrows-rotate",
        className: "regenerate-ai-summaries-button",
        label: "discourse_ai.summarization.topic.regenerate_ai_summaries",
      };
    });
  }
});
