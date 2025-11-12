import Component from "@glimmer/component";
import { ajax } from "discourse/lib/ajax";
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";
import AiTopicGist from "../components/ai-topic-gist";

export default apiInitializer((api) => {
  const settings = api.container.lookup("service:site-settings");
  const MAX_ALLOWED_GISTS_REGENERATE = 30;

  /**
   * Shared function to regenerate gists for one or more topics
   * @param {Array} topicIds - Array of topic ids
   * @param {Object} toasts - Toasts service for showing notifications
   * @param {Function} [onSuccess] - Optional callback on success
   */
  async function regenerateGists(topicIds, toasts, onSuccess = null) {
    try {
      await ajax("/discourse-ai/summarization/regen_gist", {
        type: "PUT",
        data: { topic_ids: topicIds },
      });

      // For single topic, refresh the gist data
      if (topicIds.length === 1) {
        await ajax(`/discourse-ai/summarization/t/${topicIds[0]}`, {
          type: "GET",
        });
      }

      toasts.success({
        duration: "short",
        data: {
          message: i18n("discourse_ai.summarization.topic.regenerate_success", {
            count: topicIds.length,
          }),
        },
      });

      if (onSuccess) {
        onSuccess();
      }
    } catch {
      toasts.error({
        duration: "short",
        data: {
          message: i18n("discourse_ai.summarization.topic.regenerate_error", {
            count: topicIds.length,
          }),
        },
      });
    }
  }

  api.addBulkActionButton({
    label: "discourse_ai.summarization.topic.regenerate_bulk",
    icon: "arrows-rotate",
    class: "btn-default",
    visible: ({ topics, siteSettings, currentUser }) => {
      if (topics?.length > MAX_ALLOWED_GISTS_REGENERATE) {
        return false;
      }
      return (
        siteSettings.discourse_ai_enabled &&
        siteSettings.ai_summarization_enabled &&
        siteSettings.ai_summary_gists_enabled &&
        currentUser.staff
      );
    },
    async action(opts) {
      const topics = opts.model.bulkSelectHelper.selected;
      const topicIds = topics.map((topic) => topic.id);
      const toasts = opts.toasts;

      await regenerateGists(topicIds, toasts, () => {
        // We don't call `opts.performAndRefresh` here because we want to
        // avoid `this.perform()` from being called since we don't need
        // a put request to `/topics/bulk`
        opts.model.refreshClosure?.().then(() => {
          opts.args.closeModal();
          opts.model.bulkSelectHelper.toggleBulkSelect();
          opts.showToast();
        });
      });
    },
    actionType: "performAndRefresh",
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
      if (!settings.ai_summary_gists_enabled) {
        return;
      }

      return {
        action: async () => {
          const topicId = topic.id;
          const toasts = api.container.lookup("service:toasts");

          await regenerateGists([topicId], toasts, () => {
            window.location.reload();
          });
        },
        icon: "arrows-rotate",
        className: "regenerate-gist-button",
        label: "discourse_ai.summarization.topic.regenerate",
      };
    });
  }
});
