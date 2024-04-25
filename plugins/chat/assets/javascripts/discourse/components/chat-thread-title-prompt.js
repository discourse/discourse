import { setOwner } from "@ember/application";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { NotificationLevels } from "discourse/lib/notification-levels";
import I18n from "I18n";
import ThreadSettingsModal from "discourse/plugins/chat/discourse/components/chat/modal/thread-settings";
import { THREAD_TITLE_PROMPT_THRESHOLD } from "discourse/plugins/chat/discourse/lib/chat-constants";
import UserChatThreadMembership from "discourse/plugins/chat/discourse/models/user-chat-thread-membership";

export default class ShowThreadTitlePrompt {
  @service chatApi;
  @service modal;
  @service toasts;
  @service currentUser;
  @service site;

  toastText = {
    title: I18n.t("chat.thread_title_toast.title"),
    message: I18n.t("chat.thread_title_toast.message"),
    dismissLabel: I18n.t("chat.thread_title_toast.dismiss_action"),
    primaryLabel: I18n.t("chat.thread_title_toast.primary_action"),
  };

  constructor(owner, thread) {
    setOwner(this, owner);
    this.thread = thread;
    this.createThreadMembership();
  }

  get membership() {
    return this.thread.currentUserMembership;
  }

  @action
  createThreadMembership() {
    if (this.membership || !this.currentUser.admin) {
      return;
    }

    this.thread.currentUserMembership = UserChatThreadMembership.create({
      notification_level: NotificationLevels.TRACKING,
      last_read_message_id: this.thread.lastMessageId,
      thread_title_prompt_seen: false,
    });
  }

  @action
  async updateThreadTitlePrompt() {
    if (!this.membership) {
      return;
    }

    try {
      await this.chatApi.updateCurrentUserThreadTitlePrompt(
        this.thread.channel.id,
        this.thread.id
      );
    } catch (e) {
      // eslint-disable-next-line no-console
      console.log("Couldn't save thread title prompt status", e);
      this.membership.threadTitlePromptSeen = false;
    }
  }

  @action
  disableFutureThreadTitlePrompts() {
    this.currentUser.set("user_option.show_thread_title_prompts", false);
    this.currentUser.save();
  }

  get canShowToast() {
    if (
      this.thread.user_id !== this.currentUser.id &&
      !this.currentUser.admin
    ) {
      return false;
    }

    const titleNotSet = this.thread.title === null;
    const showPrompts = this.currentUser.user_option.show_thread_title_prompts;
    const promptNotSeen = !this.membership?.threadTitlePromptSeen;
    const hasReplies = this.thread.replyCount >= THREAD_TITLE_PROMPT_THRESHOLD;

    return titleNotSet && hasReplies && showPrompts && promptNotSeen;
  }

  show() {
    if (this.site.desktopView || !this.canShowToast) {
      return;
    }

    this.toasts.default({
      duration: 5000,
      class: "thread-toast",
      data: {
        title: this.toastText.title,
        message: this.toastText.message,
        showProgressBar: true,
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
                model: this.thread,
              });

              toast.close();
            },
          },
        ],
      },
    });

    this.updateThreadTitlePrompt();
  }
}
