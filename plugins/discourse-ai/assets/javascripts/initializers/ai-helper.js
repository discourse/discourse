import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import AiComposerHelperMenu from "../discourse/components/ai-composer-helper-menu";
import ModalDiffModal from "../discourse/components/modal/diff-modal";
import { showComposerAiHelper } from "../discourse/lib/show-ai-helper";

function initializeAiHelperTrigger(api) {
  api.onToolbarCreate((toolbar) => {
    const currentUser = api.getCurrentUser();
    const modal = api.container.lookup("service:modal");

    const selectedText = (toolbarEvent) => {
      const composerContent = toolbarEvent.getText();
      const selected = toolbarEvent.selected.value;

      if (selected && selected.length > 0) {
        return selected;
      }

      if (composerContent && composerContent.length > 0) {
        return composerContent;
      }
    };
    toolbar.addButton({
      id: "ai-helper-trigger",
      group: "extras",
      icon: "discourse-sparkles",
      title: "discourse_ai.ai_helper.context_menu.trigger",
      preventFocus: true,
      hideShortcutInTitle: true,
      shortcut: "ALT+P",
      shortcutAction: (toolbarEvent) => {
        if (toolbarEvent.getText().length === 0) {
          const toasts = api.container.lookup("service:toasts");

          return toasts.error({
            class: "ai-proofread-error-toast",
            duration: 3000,
            data: {
              message: i18n("discourse_ai.ai_helper.no_content_error"),
            },
          });
        }

        const mode = currentUser?.ai_helper_prompts.find(
          (p) => p.name === "proofread"
        ).id;

        modal.show(ModalDiffModal, {
          model: {
            mode,
            selectedText: selectedText(toolbarEvent),
            toolbarEvent,
            showResultAsDiff: true,
          },
        });
      },
      condition: () =>
        showComposerAiHelper(
          api.container.lookup("service:composer").model,
          api.container.lookup("service:site-settings"),
          currentUser,
          "context_menu"
        ),
      sendAction: (event) => {
        const menu = api.container.lookup("service:menu");
        menu.show(document.querySelector(".ai-helper-trigger"), {
          identifier: "ai-composer-helper-menu",
          component: AiComposerHelperMenu,
          modalForMobile: true,
          interactive: true,
          data: {
            toolbarEvent: event,
            selectedText: selectedText(event),
          },
        });
      },
    });
  });
}

export default {
  name: "discourse-ai-helper",

  initialize() {
    withPluginApi("1.1.0", (api) => {
      initializeAiHelperTrigger(api);
    });
  },
};
