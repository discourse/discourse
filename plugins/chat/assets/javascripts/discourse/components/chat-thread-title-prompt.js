import Component from "@glimmer/component";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ThreadSettingsModal from "discourse/plugins/chat/discourse/components/chat/modal/thread-settings";
import { THREAD_TITLE_PROMPT_THRESHOLD } from "discourse/plugins/chat/discourse/lib/chat-constants";
import UserChatThreadMembership from "discourse/plugins/chat/discourse/models/user-chat-thread-membership";

export default class ChatThreadTitlePrompt extends Component {
  @service chatApi;
  @service modal;
  @service toasts;
  @service currentUser;
  @service site;

  toastText = {
    title: i18n("chat.thread_title_toast.title"),
    message: i18n("chat.thread_title_toast.message"),
    dismissLabel: i18n("chat.thread_title_toast.dismiss_action"),
    primaryLabel: i18n("chat.thread_title_toast.primary_action"),
  };

  constructor() {
    super(...arguments);

    next(() => {
      if (this.canShowToast) {
        this.show();
        this.updateThreadTitlePrompt();
      }
    });
  }

  get membership() {
    return this.args.thread.currentUserMembership;
  }

  @action
  async updateThreadTitlePrompt() {
    try {
      const result = await this.chatApi.updateCurrentUserThreadTitlePrompt(
        this.args.thread.channel.id,
        this.args.thread.id
      );

      this.args.thread.currentUserMembership = UserChatThreadMembership.create(
        result.membership
      );
    } catch (e) {
      // eslint-disable-next-line no-console
      console.log("Couldn't save thread title prompt status", e);

      if (this.membership) {
        this.membership.threadTitlePromptSeen = false;
      }
    }
  }

  @action
  disableFutureThreadTitlePrompts() {
    this.currentUser.set("user_option.show_thread_title_prompts", false);
    this.currentUser.save();
  }

  get canShowToast() {
    if (
      this.site.desktopView ||
      (this.args.thread.originalMessage?.user?.id !== this.currentUser.id &&
        !this.currentUser.admin)
    ) {
      return false;
    }
    const titleNotSet = this.args.thread.title === null;
    const hasReplies =
      this.args.thread.replyCount >= THREAD_TITLE_PROMPT_THRESHOLD;
    const showPrompts = this.currentUser.user_option.show_thread_title_prompts;
    const promptNotSeen = !this.membership?.threadTitlePromptSeen;
    return titleNotSet && hasReplies && showPrompts && promptNotSeen;
  }

  show() {
    this.toasts.default({
      duration: 5000,
      showProgressBar: true,
      class: "thread-toast",
      data: {
        title: this.toastText.title,
        message: this.toastText.message,
        actions: [
          {
            label: this.toastText.dismissLabel,
            class: "btn-link toast-hide",
            action: (toast) => {
              this.disableFutureThreadTitlePrompts();
              toast.close();
            },
          },
          {
            label: this.toastText.primaryLabel,
            class: "btn-primary toast-action",
            action: (toast) => {
              this.modal.show(ThreadSettingsModal, {
                model: this.args.thread,
              });

              toast.close();
            },
          },
        ],
      },
    });
  }
}
