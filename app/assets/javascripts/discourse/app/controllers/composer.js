import Composer, { SAVE_ICONS, SAVE_LABELS } from "discourse/models/composer";
import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { action, computed } from "@ember/object";
import { alias, and, or, reads } from "@ember/object/computed";
import {
  authorizesOneOrMoreExtensions,
  uploadIcon,
} from "discourse/lib/uploads";
import { cancel, run, scheduleOnce } from "@ember/runloop";
import {
  cannotPostAgain,
  durationTextFromSeconds,
} from "discourse/helpers/slow-mode";
import discourseComputed, {
  observes,
  on,
} from "discourse-common/utils/decorators";
import DiscourseURL from "discourse/lib/url";
import Draft from "discourse/models/draft";
import I18n from "I18n";
import { iconHTML } from "discourse-common/lib/icon-library";
import { Promise } from "rsvp";
import bootbox from "bootbox";
import { buildQuote } from "discourse/lib/quote";
import deprecated from "discourse-common/lib/deprecated";
import discourseDebounce from "discourse-common/lib/debounce";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { getOwner } from "discourse-common/lib/get-owner";
import getURL from "discourse-common/lib/get-url";
import { isEmpty } from "@ember/utils";
import { isTesting } from "discourse-common/config/environment";
import { inject as service } from "@ember/service";
import { shortDate } from "discourse/lib/formatter";
import showModal from "discourse/lib/show-modal";

function loadDraft(store, opts) {
  let promise = Promise.resolve();

  opts = opts || {};

  let draft = opts.draft;
  const draftKey = opts.draftKey;
  const draftSequence = opts.draftSequence;

  try {
    if (draft && typeof draft === "string") {
      draft = JSON.parse(draft);
    }
  } catch (error) {
    draft = null;
    Draft.clear(draftKey, draftSequence);
  }
  if (
    draft &&
    ((draft.title && draft.title !== "") || (draft.reply && draft.reply !== ""))
  ) {
    const composer = store.createRecord("composer");
    const serializedFields = Composer.serializedFieldsForDraft();

    let attrs = {
      draftKey,
      draftSequence,
      draft: true,
      composerState: Composer.DRAFT,
      topic: opts.topic,
    };

    serializedFields.forEach((f) => {
      attrs[f] = draft[f] || opts[f];
    });

    promise = promise.then(() => composer.open(attrs)).then(() => composer);
  }

  return promise;
}

const _popupMenuOptionsCallbacks = [];

let _checkDraftPopup = !isTesting();

export function toggleCheckDraftPopup(enabled) {
  _checkDraftPopup = enabled;
}

export function clearPopupMenuOptionsCallback() {
  _popupMenuOptionsCallbacks.length = 0;
}

export function addPopupMenuOptionsCallback(callback) {
  _popupMenuOptionsCallbacks.push(callback);
}

export default Controller.extend({
  topicController: controller("topic"),
  router: service(),

  checkedMessages: false,
  messageCount: null,
  showEditReason: false,
  editReason: null,
  scopedCategoryId: null,
  prioritizedCategoryId: null,
  lastValidatedAt: null,
  isUploading: false,
  isProcessingUpload: false,
  topic: null,
  linkLookup: null,
  showPreview: true,
  forcePreview: and("site.mobileView", "showPreview"),
  whisperOrUnlistTopic: or("isWhispering", "model.unlistTopic"),
  categories: alias("site.categoriesList"),

  @on("init")
  _setupPreview() {
    const val = this.site.mobileView
      ? false
      : this.keyValueStore.get("composer.showPreview") || "true";
    this.set("showPreview", val === "true");
  },

  @discourseComputed("showPreview")
  toggleText(showPreview) {
    return showPreview
      ? I18n.t("composer.hide_preview")
      : I18n.t("composer.show_preview");
  },

  @observes("showPreview")
  showPreviewChanged() {
    if (!this.site.mobileView) {
      this.keyValueStore.set({
        key: "composer.showPreview",
        value: this.showPreview,
      });
    }
  },

  @discourseComputed(
    "model.replyingToTopic",
    "model.creatingPrivateMessage",
    "model.targetRecipients",
    "model.composeState"
  )
  focusTarget(replyingToTopic, creatingPM, usernames, composeState) {
    // Focus on usernames if it's blank or if it's just you
    usernames = usernames || "";
    if (
      (creatingPM && usernames.length === 0) ||
      usernames === this.currentUser.username
    ) {
      return "usernames";
    }

    if (replyingToTopic) {
      return "reply";
    }

    if (composeState === Composer.FULLSCREEN) {
      return "editor";
    }

    return "title";
  },

  showToolbar: computed({
    get() {
      const keyValueStore = getOwner(this).lookup("key-value-store:main");
      const storedVal = keyValueStore.get("toolbar-enabled");
      if (this._toolbarEnabled === undefined && storedVal === undefined) {
        // iPhone 6 is 375, anything narrower and toolbar should
        // be default disabled.
        // That said we should remember the state
        this._toolbarEnabled =
          window.innerWidth > 370 && !this.capabilities.isAndroid;
      }
      return this._toolbarEnabled || storedVal === "true";
    },
    set(key, val) {
      const keyValueStore = getOwner(this).lookup("key-value-store:main");
      this._toolbarEnabled = val;
      keyValueStore.set({
        key: "toolbar-enabled",
        value: val ? "true" : "false",
      });
      return val;
    },
  }),

  topicModel: alias("topicController.model"),

  @discourseComputed("model.canEditTitle", "model.creatingPrivateMessage")
  canEditTags(canEditTitle, creatingPrivateMessage) {
    if (creatingPrivateMessage && (this.site.mobileView || !this.isStaffUser)) {
      return false;
    }

    return (
      this.site.can_tag_topics &&
      canEditTitle &&
      (!this.get("model.topic.isPrivateMessage") || this.site.can_tag_pms)
    );
  },

  @discourseComputed("model.editingPost", "model.topic.details.can_edit")
  disableCategoryChooser(editingPost, canEditTopic) {
    return editingPost && !canEditTopic;
  },

  @discourseComputed("model.editingPost", "model.topic.canEditTags")
  disableTagsChooser(editingPost, canEditTags) {
    return editingPost && !canEditTags;
  },

  isStaffUser: reads("currentUser.staff"),

  canUnlistTopic: and("model.creatingTopic", "isStaffUser"),

  @discourseComputed("canWhisper", "replyingToWhisper")
  showWhisperToggle(canWhisper, replyingToWhisper) {
    return canWhisper && !replyingToWhisper;
  },

  @discourseComputed("model.post")
  replyingToWhisper(repliedToPost) {
    return (
      repliedToPost && repliedToPost.post_type === this.site.post_types.whisper
    );
  },

  isWhispering: or("replyingToWhisper", "model.whisper"),

  @discourseComputed("model.action", "isWhispering", "model.privateMessage")
  saveIcon(modelAction, isWhispering, privateMessage) {
    if (isWhispering) {
      return "far-eye-slash";
    }
    if (privateMessage && modelAction === Composer.REPLY) {
      return "envelope";
    }

    return SAVE_ICONS[modelAction];
  },

  // Note we update when some other attributes like tag/category change to allow
  // text customizations to use those.
  @discourseComputed(
    "model.action",
    "isWhispering",
    "model.editConflict",
    "model.privateMessage",
    "model.tags",
    "model.category"
  )
  saveLabel(modelAction, isWhispering, editConflict, privateMessage) {
    let result = this.model.customizationFor("saveLabel");
    if (result) {
      return result;
    }

    if (editConflict) {
      return "composer.overwrite_edit";
    } else if (isWhispering) {
      return "composer.create_whisper";
    } else if (privateMessage && modelAction === Composer.REPLY) {
      return "composer.create_pm";
    }

    return SAVE_LABELS[modelAction];
  },

  @discourseComputed("isStaffUser", "model.action")
  canWhisper(isStaffUser, modelAction) {
    return (
      this.siteSettings.enable_whispers &&
      isStaffUser &&
      Composer.REPLY === modelAction
    );
  },

  _setupPopupMenuOption(callback) {
    let option = callback(this);
    if (typeof option === "undefined") {
      return null;
    }

    if (typeof option.condition === "undefined") {
      option.condition = true;
    } else if (typeof option.condition === "boolean") {
      // uses existing value
    } else {
      option.condition = this.get(option.condition);
    }

    return option;
  },

  @discourseComputed("model.requiredCategoryMissing", "model.replyLength")
  disableTextarea(requiredCategoryMissing, replyLength) {
    return requiredCategoryMissing && replyLength === 0;
  },

  @discourseComputed("model.composeState", "model.creatingTopic", "model.post")
  popupMenuOptions(composeState) {
    if (composeState === "open" || composeState === "fullscreen") {
      const options = [];

      options.push(
        this._setupPopupMenuOption(() => {
          return {
            action: "toggleInvisible",
            icon: "far-eye-slash",
            label: "composer.toggle_unlisted",
            condition: "canUnlistTopic",
          };
        })
      );

      if (this.site.mobileView) {
        options.push(
          this._setupPopupMenuOption(() => {
            return {
              action: "applyUnorderedList",
              icon: "list-ul",
              label: "composer.ulist_title",
            };
          })
        );

        options.push(
          this._setupPopupMenuOption(() => {
            return {
              action: "applyOrderedList",
              icon: "list-ol",
              label: "composer.olist_title",
            };
          })
        );
      }

      options.push(
        this._setupPopupMenuOption(() => {
          return {
            action: "toggleWhisper",
            icon: "far-eye-slash",
            label: "composer.toggle_whisper",
            condition: "showWhisperToggle",
          };
        })
      );

      return options.concat(
        _popupMenuOptionsCallbacks
          .map((callback) => this._setupPopupMenuOption(callback))
          .filter((o) => o)
      );
    }
  },

  @discourseComputed("model.creatingPrivateMessage", "model.targetRecipients")
  showWarning(creatingPrivateMessage, usernames) {
    if (!this.get("currentUser.staff")) {
      return false;
    }

    const hasTargetGroups = this.get("model.hasTargetGroups");

    // We need exactly one user to issue a warning
    if (
      isEmpty(usernames) ||
      usernames.split(",").length !== 1 ||
      hasTargetGroups
    ) {
      return false;
    }

    return creatingPrivateMessage;
  },

  @discourseComputed("model.topic.title")
  draftTitle(topicTitle) {
    return emojiUnescape(escapeExpression(topicTitle));
  },

  @discourseComputed
  allowUpload() {
    return authorizesOneOrMoreExtensions(
      this.currentUser.staff,
      this.siteSettings
    );
  },

  @discourseComputed()
  uploadIcon() {
    return uploadIcon(this.currentUser.staff, this.siteSettings);
  },

  // Use this to open the composer when you are not sure whether it is
  // already open and whether it already has a draft being worked on. Supports
  // options to append text once the composer is open if required.
  //
  // opts:
  //
  // - fallbackToNewTopic: if true, and there is no draft, the composer will
  // be opened with the create_topic action and a new topic draft key
  // - insertText: the text to append to the composer once it is opened
  // - openOpts: this object will be passed to this.open if fallbackToNewTopic is
  // true
  @action
  focusComposer(opts = {}) {
    if (this.get("model.viewOpen")) {
      this._focusAndInsertText(opts.insertText);
    } else {
      const opened = this.openIfDraft();
      if (!opened && opts.fallbackToNewTopic) {
        this.open(
          Object.assign(
            {
              action: Composer.CREATE_TOPIC,
              draftKey: Composer.NEW_TOPIC_KEY,
            },
            opts.openOpts || {}
          )
        ).then(() => {
          this._focusAndInsertText(opts.insertText);
        });
      } else if (opened) {
        this._focusAndInsertText(opts.insertText);
      }
    }
  },

  _focusAndInsertText(insertText) {
    scheduleOnce("afterRender", () => {
      const input = document.querySelector("textarea.d-editor-input");
      input && input.focus();

      if (insertText) {
        this.model.appendText(insertText, null, { new_line: true });
      }
    });
  },

  @action
  openIfDraft(event) {
    if (this.get("model.viewDraft")) {
      // when called from shortcut, ensure we don't propagate the key to
      // the composer input title
      if (event) {
        event.preventDefault();
        event.stopPropagation();
      }

      this.set("model.composeState", Composer.OPEN);
      return true;
    }

    return false;
  },

  actions: {
    togglePreview() {
      this.toggleProperty("showPreview");
    },

    closeComposer() {
      this.close();
    },

    openComposer(options, post, topic) {
      this.open(options).then(() => {
        let url;
        if (post) {
          url = post.url;
        }
        if (!post && topic) {
          url = topic.url;
        }

        let topicTitle;
        if (topic) {
          topicTitle = topic.title;
        }

        if (!url || !topicTitle) {
          return;
        }

        url = `${location.protocol}//${location.host}${url}`;
        const link = `[${escapeExpression(topicTitle)}](${url})`;
        const continueDiscussion = I18n.t("post.continue_discussion", {
          postLink: link,
        });

        const reply = this.get("model.reply");
        if (!reply || !reply.includes(continueDiscussion)) {
          this.model.prependText(continueDiscussion, {
            new_line: true,
          });
        }
      });
    },

    cancelUpload() {
      this.set("model.uploadCancelled", true);
    },

    onPopupMenuAction(menuAction) {
      this.send(menuAction);
    },

    storeToolbarState(toolbarEvent) {
      this.set("toolbarEvent", toolbarEvent);
    },

    typed() {
      this.checkReplyLength();
      this.model.typing();
    },

    cancelled() {
      this.send("hitEsc");
    },

    addLinkLookup(linkLookup) {
      this.set("linkLookup", linkLookup);
    },

    afterRefresh($preview) {
      const topic = this.get("model.topic");
      const linkLookup = this.linkLookup;

      if (!topic || !linkLookup) {
        return;
      }

      // Don't check if there's only one post
      if (topic.posts_count === 1) {
        return;
      }

      const post = this.get("model.post");
      const $links = $("a[href]", $preview);
      $links.each((idx, l) => {
        const href = l.href;
        if (href && href.length) {
          // skip links added by watched words
          if (l.dataset.word !== undefined) {
            return true;
          }

          // skip links in quotes and oneboxes
          for (let element = l; element; element = element.parentElement) {
            if (
              element.tagName === "DIV" &&
              element.classList.contains("d-editor-preview")
            ) {
              break;
            }

            if (
              element.tagName === "ASIDE" &&
              element.classList.contains("quote")
            ) {
              return true;
            }

            if (
              element.tagName === "ASIDE" &&
              element.classList.contains("onebox") &&
              href !== element.dataset["onebox-src"]
            ) {
              return true;
            }
          }

          const [linkWarn, linkInfo] = linkLookup.check(post, href);

          if (linkWarn && !this.get("isWhispering")) {
            const body = I18n.t("composer.duplicate_link", {
              domain: linkInfo.domain,
              username: linkInfo.username,
              post_url: topic.urlForPostNumber(linkInfo.post_number),
              ago: shortDate(linkInfo.posted_at),
            });
            this.appEvents.trigger("composer-messages:create", {
              extraClass: "custom-body",
              templateName: "custom-body",
              body,
            });
            return false;
          }
        }
        return true;
      });
    },

    toggleWhisper() {
      this.toggleProperty("model.whisper");
    },

    toggleInvisible() {
      this.toggleProperty("model.unlistTopic");
    },

    toggleToolbar() {
      this.toggleProperty("showToolbar");
    },

    // Toggle the reply view
    toggle() {
      this.closeAutocomplete();

      if (
        isEmpty(this.get("model.reply")) &&
        isEmpty(this.get("model.title"))
      ) {
        this.close();
      } else {
        if (
          this.get("model.composeState") === Composer.OPEN ||
          this.get("model.composeState") === Composer.FULLSCREEN
        ) {
          this.shrink();
        } else {
          this.cancelComposer();
        }
      }

      return false;
    },

    fullscreenComposer() {
      this.toggleFullscreen();
      return false;
    },

    // Import a quote from the post
    importQuote(toolbarEvent) {
      const postStream = this.get("topic.postStream");
      let postId = this.get("model.post.id");

      // If there is no current post, use the first post id from the stream
      if (!postId && postStream) {
        postId = postStream.get("stream.firstObject");
      }

      // If we're editing a post, fetch the reply when importing a quote
      if (this.get("model.editingPost")) {
        const replyToPostNumber = this.get("model.post.reply_to_post_number");
        if (replyToPostNumber) {
          const replyPost = postStream.posts.findBy(
            "post_number",
            replyToPostNumber
          );

          if (replyPost) {
            postId = replyPost.id;
          }
        }
      }

      if (postId) {
        this.set("model.loading", true);

        return this.store.find("post", postId).then((post) => {
          const quote = buildQuote(post, post.raw, {
            full: true,
          });

          toolbarEvent.addText(quote);
          this.set("model.loading", false);
        });
      }
    },

    cancel() {
      this.cancelComposer();
    },

    save(ignore, event) {
      this.save(false, {
        jump:
          !(event?.shiftKey && this.get("model.replyingToTopic")) &&
          !this.skipJumpOnSave,
      });
    },

    displayEditReason() {
      this.set("showEditReason", true);
    },

    hitEsc() {
      if (
        document.querySelectorAll(".emoji-picker-modal.fadeIn").length === 1
      ) {
        this.appEvents.trigger("emoji-picker:close");
        return;
      }

      if ((this.messageCount || 0) > 0) {
        this.appEvents.trigger("composer-messages:close");
        return;
      }

      if (this.get("model.viewOpen") || this.get("model.viewFullscreen")) {
        this.shrink();
      }
    },

    groupsMentioned(groups) {
      if (
        !this.get("model.creatingPrivateMessage") &&
        !this.get("model.topic.isPrivateMessage")
      ) {
        groups.forEach((group) => {
          let body;
          const groupLink = getURL(`/g/${group.name}/members`);
          const maxMentions = parseInt(group.max_mentions, 10);
          const userCount = parseInt(group.user_count, 10);

          if (maxMentions < userCount) {
            body = I18n.t("composer.group_mentioned_limit", {
              group: `@${group.name}`,
              count: maxMentions,
              group_link: groupLink,
            });
          } else if (group.user_count > 0) {
            body = I18n.t("composer.group_mentioned", {
              group: `@${group.name}`,
              count: userCount,
              group_link: groupLink,
            });
          }

          if (body) {
            this.appEvents.trigger("composer-messages:create", {
              extraClass: "custom-body",
              templateName: "custom-body",
              body,
            });
          }
        });
      }
    },

    cannotSeeMention(mentions) {
      mentions.forEach((mention) => {
        this.appEvents.trigger("composer-messages:create", {
          extraClass: "custom-body",
          templateName: "custom-body",
          body: I18n.t(`composer.cannot_see_mention.${mention.reason}`, {
            username: mention.name,
          }),
        });
      });
    },

    hereMention(count) {
      this.appEvents.trigger("composer-messages:create", {
        extraClass: "custom-body",
        templateName: "custom-body",
        body: I18n.t("composer.here_mention", {
          here: this.siteSettings.here_mention,
          count,
        }),
      });
    },

    applyUnorderedList() {
      this.toolbarEvent.applyList("* ", "list_item");
    },

    applyOrderedList() {
      this.toolbarEvent.applyList(
        (i) => (!i ? "1. " : `${parseInt(i, 10) + 1}. `),
        "list_item"
      );
    },
  },

  disableSubmit: or("model.loading", "isUploading", "isProcessingUpload"),

  save(force, options = {}) {
    if (this.disableSubmit) {
      return;
    }

    // Clear the warning state if we're not showing the checkbox anymore
    if (!this.showWarning) {
      this.set("model.isWarning", false);
    }

    if (this.site.mobileView && this.showPreview) {
      this.set("showPreview", false);
    }

    const composer = this.model;

    if (composer.cantSubmitPost) {
      this.set("lastValidatedAt", Date.now());
      return;
    }

    const topic = composer.topic;
    const slowModePost =
      topic && topic.slow_mode_seconds && topic.user_last_posted_at;
    const notEditing = this.get("model.action") !== "edit";

    // Editing a topic in slow mode is directly handled by the backend.
    if (slowModePost && notEditing) {
      if (
        cannotPostAgain(
          this.currentUser,
          topic.slow_mode_seconds,
          topic.user_last_posted_at
        )
      ) {
        const canPostAt = new moment(topic.user_last_posted_at).add(
          topic.slow_mode_seconds,
          "seconds"
        );
        const timeLeft = moment().diff(canPostAt, "seconds");
        const message = I18n.t("composer.slow_mode.error", {
          timeLeft: durationTextFromSeconds(timeLeft),
        });

        bootbox.alert(message);
        return;
      } else {
        // Edge case where the user tries to post again immediately.
        topic.set("user_last_posted_at", new Date().toISOString());
      }
    }

    composer.set("disableDrafts", true);

    // for now handle a very narrow use case
    // if we are replying to a topic
    // AND are on on a different topic
    // AND topic is open (or we are staff)
    // --> pop the window up
    if (!force && composer.replyingToTopic) {
      const currentTopic = this.topicModel;

      if (!currentTopic) {
        this.save(true);
        return;
      }

      if (
        currentTopic.id !== composer.get("topic.id") &&
        (this.isStaffUser || !currentTopic.closed)
      ) {
        const message =
          "<h1>" + I18n.t("composer.posting_not_on_topic") + "</h1>";

        let buttons = [
          {
            label: I18n.t("composer.cancel"),
            class: "d-modal-cancel",
            link: true,
          },
        ];

        buttons.push({
          label:
            I18n.t("composer.reply_here") +
            "<br/><div class='topic-title overflow-ellipsis'>" +
            currentTopic.get("fancyTitle") +
            "</div>",
          class: "btn btn-reply-here",
          callback: () => {
            composer.setProperties({ topic: currentTopic, post: null });
            this.save(true);
          },
        });

        buttons.push({
          label:
            I18n.t("composer.reply_original") +
            "<br/><div class='topic-title overflow-ellipsis'>" +
            this.get("model.topic.fancyTitle") +
            "</div>",
          class: "btn-primary btn-reply-on-original",
          callback: () => this.save(true),
        });

        bootbox.dialog(message, buttons, { classes: "reply-where-modal" });
        return;
      }
    }

    let staged = false;

    // TODO: This should not happen in model
    const imageSizes = {};
    document
      .querySelectorAll("#reply-control .d-editor-preview img")
      .forEach((e) => {
        const src = e.src;

        if (src && src.length) {
          imageSizes[src] = { width: e.naturalWidth, height: e.naturalHeight };
        }
      });

    const promise = composer
      .save({ imageSizes, editReason: this.editReason })
      .then((result) => {
        this.appEvents.trigger("composer:saved");

        if (result.responseJson.action === "enqueued") {
          this.send("postWasEnqueued", result.responseJson);
          if (result.responseJson.pending_post) {
            let pendingPosts = this.get("topicController.model.pending_posts");
            if (pendingPosts) {
              pendingPosts.pushObject(result.responseJson.pending_post);
            }
          }

          return this.destroyDraft().then(() => {
            this.close();
            this.appEvents.trigger("post-stream:refresh");
            return result;
          });
        }

        if (this.get("model.editingPost")) {
          this.appEvents.trigger("composer:edited-post");
          this.appEvents.trigger("post-stream:refresh", {
            id: parseInt(result.responseJson.id, 10),
          });
          if (result.responseJson.post.post_number === 1) {
            this.appEvents.trigger("header:update-topic", composer.topic);
          }
        } else {
          this.appEvents.trigger("post-stream:refresh");
        }

        if (result.responseJson.action === "create_post") {
          this.appEvents.trigger("composer:created-post");
          this.appEvents.trigger(
            "post:highlight",
            result.payload.post_number,
            options
          );
        }

        if (this.get("model.draftKey") === Composer.NEW_TOPIC_KEY) {
          this.currentUser.set("has_topic_draft", false);
        }

        if (result.responseJson.route_to) {
          this.destroyDraft();
          if (result.responseJson.message) {
            return bootbox.alert(result.responseJson.message, () => {
              DiscourseURL.routeTo(result.responseJson.route_to);
            });
          }
          return DiscourseURL.routeTo(result.responseJson.route_to);
        }

        this.close();

        this.currentUser.set("any_posts", true);

        const post = result.target;

        if (post && !staged && options.jump !== false) {
          DiscourseURL.routeTo(post.url, {
            keepFilter: true,
            skipIfOnScreen: true,
          });
        }
      })
      .catch((error) => {
        composer.set("disableDrafts", false);
        if (error) {
          this.appEvents.one("composer:will-open", () => bootbox.alert(error));
        }
      });

    if (
      this.router.currentRouteName.split(".")[0] === "topic" &&
      composer.get("topic.id") === this.get("topicModel.id")
    ) {
      staged = composer.get("stagedPost");
    }

    this.appEvents.trigger("post-stream:posted", staged);

    this.messageBus.pause();
    promise.finally(() => this.messageBus.resume());

    return promise;
  },

  // Notify the composer messages controller that a reply has been typed. Some
  // messages only appear after typing.
  checkReplyLength() {
    if (!isEmpty("model.reply")) {
      this.appEvents.trigger("composer:typed-reply");
    }
  },

  /**
    Open the composer view

    @method open
    @param {Object} opts Options for creating a post
      @param {String} opts.action The action we're performing: edit, reply, createTopic, createSharedDraft, privateMessage
      @param {String} opts.draftKey
      @param {Post} [opts.post] The post we're replying to
      @param {Topic} [opts.topic] The topic we're replying to
      @param {String} [opts.quote] If we're opening a reply from a quote, the quote we're making
      @param {Boolean} [opts.ignoreIfChanged]
      @param {Boolean} [opts.disableScopedCategory]
      @param {Number} [opts.categoryId] Sets `scopedCategoryId` and `categoryId` on the Composer model
      @param {Number} [opts.prioritizedCategoryId]
      @param {String} [opts.draftSequence]
      @param {Boolean} [opts.skipDraftCheck]
      @param {Boolean} [opts.skipJumpOnSave] Option to skip navigating to the post when saved in this composer session
  **/
  open(opts) {
    opts = opts || {};

    if (!opts.draftKey) {
      throw new Error("composer opened without a proper draft key");
    }

    let composerModel = this.model;

    if (
      opts.ignoreIfChanged &&
      composerModel &&
      composerModel.composeState !== Composer.CLOSED
    ) {
      return;
    }

    this.setProperties({
      showEditReason: false,
      editReason: null,
      scopedCategoryId: null,
      prioritizedCategoryId: null,
      skipAutoSave: true,
    });

    this.set("skipJumpOnSave", !!opts.skipJumpOnSave);

    // Scope the categories drop down to the category we opened the composer with.
    if (opts.categoryId && !opts.disableScopedCategory) {
      const category = this.site.categories.findBy("id", opts.categoryId);
      if (category) {
        this.set("scopedCategoryId", opts.categoryId);
      }
    }

    if (opts.prioritizedCategoryId) {
      const category = this.site.categories.findBy(
        "id",
        opts.prioritizedCategoryId
      );
      if (category) {
        this.set("prioritizedCategoryId", opts.prioritizedCategoryId);
      }
    }

    // If we want a different draft than the current composer, close it and clear our model.
    if (
      composerModel &&
      opts.draftKey !== composerModel.draftKey &&
      composerModel.composeState === Composer.DRAFT
    ) {
      this.close();
      composerModel = null;
    }

    let promise = new Promise((resolve, reject) => {
      if (composerModel && composerModel.replyDirty) {
        // If we're already open, we don't have to do anything
        if (
          composerModel.composeState === Composer.OPEN &&
          composerModel.draftKey === opts.draftKey &&
          !opts.action
        ) {
          return resolve();
        }

        // If it's the same draft, just open it up again.
        if (
          composerModel.composeState === Composer.DRAFT &&
          composerModel.draftKey === opts.draftKey
        ) {
          composerModel.set("composeState", Composer.OPEN);
          if (!opts.action) {
            return resolve();
          }
        }

        return this.cancelComposer()
          .then(() => this.open(opts))
          .then(resolve, reject);
      }

      if (composerModel && composerModel.action !== opts.action) {
        composerModel.setProperties({ unlistTopic: false, whisper: false });
      }

      // we need a draft sequence for the composer to work
      if (opts.draftSequence === undefined) {
        return Draft.get(opts.draftKey)
          .then((data) => {
            if (opts.skipDraftCheck) {
              data.draft = undefined;
              return data;
            }
            return this.confirmDraftAbandon(data);
          })
          .then((data) => {
            if (!opts.draft && data.draft) {
              opts.draft = data.draft;
            }
            opts.draftSequence = data.draft_sequence;
            return this._setModel(composerModel, opts);
          })
          .then(resolve, reject);
      }
      // otherwise, do the draft check async
      else if (!opts.draft && !opts.skipDraftCheck) {
        Draft.get(opts.draftKey)
          .then((data) => {
            return this.confirmDraftAbandon(data);
          })
          .then((data) => {
            if (data.draft) {
              opts.draft = data.draft;
              opts.draftSequence = data.draft_sequence;
              return this.open(opts);
            }
          });
      }

      this._setModel(composerModel, opts).then(resolve, reject);
    });

    promise = promise.finally(() => {
      this.skipAutoSave = false;
    });
    return promise;
  },

  // Given a potential instance and options, set the model for this composer.
  _setModel(optionalComposerModel, opts) {
    let promise = Promise.resolve();

    this.set("linkLookup", null);

    promise = promise.then(() => {
      if (opts.draft) {
        return loadDraft(this.store, opts).then((model) => {
          if (!model) {
            throw new Error("draft was not found");
          }
          return model;
        });
      } else {
        let model =
          optionalComposerModel || this.store.createRecord("composer");
        return model.open(opts).then(() => model);
      }
    });

    promise.then((composerModel) => {
      this.set("model", composerModel);

      composerModel.setProperties({
        composeState: Composer.OPEN,
        isWarning: false,
        hasTargetGroups: opts.hasGroups,
      });

      if (!this.model.targetRecipients) {
        if (opts.usernames) {
          deprecated("`usernames` is deprecated, use `recipients` instead.");
          this.model.set("targetRecipients", opts.usernames);
        } else if (opts.recipients) {
          this.model.set("targetRecipients", opts.recipients);
        }
      }

      if (
        opts.topicTitle &&
        opts.topicTitle.length <= this.siteSettings.max_topic_title_length
      ) {
        this.model.set("title", opts.topicTitle);
      }

      if (opts.topicCategoryId) {
        this.model.set("categoryId", opts.topicCategoryId);
      }

      if (opts.topicTags && this.site.can_tag_topics) {
        let tags = escapeExpression(opts.topicTags)
          .split(",")
          .slice(0, this.siteSettings.max_tags_per_topic);

        tags.forEach(
          (tag, index, array) =>
            (array[index] = tag.substring(0, this.siteSettings.max_tag_length))
        );

        this.model.set("tags", tags);
      }

      if (opts.topicBody) {
        this.model.set("reply", opts.topicBody);
      }
    });

    return promise;
  },

  viewNewReply() {
    DiscourseURL.routeTo(this.get("model.createdPost.url"));
    this.close();
    return false;
  },

  destroyDraft(draftSequence = null) {
    const key = this.get("model.draftKey");
    if (key) {
      if (key === Composer.NEW_TOPIC_KEY) {
        this.currentUser.set("has_topic_draft", false);
      }

      if (this._saveDraftPromise) {
        return this._saveDraftPromise.then(() => this.destroyDraft());
      }

      const sequence = draftSequence || this.get("model.draftSequence");
      return Draft.clear(key, sequence).then(() =>
        this.appEvents.trigger("draft:destroyed", key)
      );
    } else {
      return Promise.resolve();
    }
  },

  confirmDraftAbandon(data) {
    if (!data.draft) {
      return data;
    }

    // do not show abandon dialog if old draft is clean
    const draft = JSON.parse(data.draft);
    if (draft.reply === draft.originalText) {
      data.draft = null;
      return data;
    }

    if (_checkDraftPopup) {
      return new Promise((resolve) => {
        bootbox.dialog(I18n.t("drafts.abandon.confirm"), [
          {
            label: I18n.t("drafts.abandon.no_value"),
            callback: () => resolve(data),
          },
          {
            label: I18n.t("drafts.abandon.yes_value"),
            class: "btn-danger",
            icon: iconHTML("far-trash-alt"),
            callback: () => {
              this.destroyDraft(data.draft_sequence).finally(() => {
                data.draft = null;
                resolve(data);
              });
            },
          },
        ]);
      });
    } else {
      data.draft = null;
      return data;
    }
  },

  cancelComposer() {
    this.skipAutoSave = true;

    if (this._saveDraftDebounce) {
      cancel(this._saveDraftDebounce);
    }

    let promise = new Promise((resolve, reject) => {
      if (this.get("model.hasMetaData") || this.get("model.replyDirty")) {
        const modal = showModal("discard-draft", {
          model: this.model,
          modalClass: "discard-draft-modal",
        });
        modal.setProperties({
          onDestroyDraft: () => {
            this.destroyDraft()
              .then(() => {
                this.model.clearState();
                this.close();
              })
              .finally(() => {
                resolve();
              });
          },
          onSaveDraft: () => {
            this._saveDraft();
            this.model.clearState();
            this.close();
            resolve();
          },
          // needed to resume saving drafts if composer stays open
          onDismissModal: () => reject(),
        });
      } else {
        // it is possible there is some sort of crazy draft with no body ... just give up on it
        this.destroyDraft()
          .then(() => {
            this.model.clearState();
            this.close();
          })
          .finally(() => {
            resolve();
          });
      }
    });

    return promise.finally(() => {
      this.skipAutoSave = false;
    });
  },

  shrink() {
    if (
      this.get("model.replyDirty") ||
      (this.get("model.canEditTitle") && this.get("model.titleDirty"))
    ) {
      this.collapse();
    } else {
      this.close();
    }
  },

  _saveDraft() {
    const model = this.model;
    if (model) {
      if (model.draftSaving) {
        // in test debounce is Ember.run, this will cause
        // an infinite loop
        if (!isTesting()) {
          this._saveDraftDebounce = discourseDebounce(
            this,
            this._saveDraft,
            2000
          );
        }
      } else {
        this._saveDraftPromise = model
          .saveDraft(this.currentUser)
          .finally(() => {
            this._lastDraftSaved = Date.now();
            this._saveDraftPromise = null;
          });
      }
    }
  },

  @observes("model.reply", "model.title")
  _shouldSaveDraft() {
    if (
      this.model &&
      !this.model.loading &&
      !this.skipAutoSave &&
      !this.model.disableDrafts
    ) {
      if (!this._lastDraftSaved) {
        // pretend so we get a save unconditionally in 15 secs
        this._lastDraftSaved = Date.now();
      }
      if (Date.now() - this._lastDraftSaved > 15000) {
        this._saveDraft();
      } else {
        let method = isTesting() ? run : discourseDebounce;
        this._saveDraftDebounce = method(this, this._saveDraft, 2000);
      }
    }
  },

  @discourseComputed("model.categoryId", "lastValidatedAt")
  categoryValidation(categoryId, lastValidatedAt) {
    if (!this.siteSettings.allow_uncategorized_topics && !categoryId) {
      return EmberObject.create({
        failed: true,
        reason: I18n.t("composer.error.category_missing"),
        lastShownAt: lastValidatedAt,
      });
    }
  },

  @discourseComputed("model.category", "model.tags", "lastValidatedAt")
  tagValidation(category, tags, lastValidatedAt) {
    const tagsArray = tags || [];
    if (this.site.can_tag_topics && !this.currentUser.staff && category) {
      if (
        category.minimum_required_tags > tagsArray.length ||
        (category.required_tag_groups &&
          category.min_tags_from_required_group > tagsArray.length)
      ) {
        return EmberObject.create({
          failed: true,
          reason: I18n.t("composer.error.tags_missing", {
            count:
              category.minimum_required_tags ||
              category.min_tags_from_required_group,
          }),
          lastShownAt: lastValidatedAt,
        });
      }
    }
  },

  collapse() {
    this._saveDraft();
    this.set("model.composeState", Composer.DRAFT);
  },

  toggleFullscreen() {
    this._saveDraft();
    if (this.get("model.composeState") === Composer.FULLSCREEN) {
      this.set("model.composeState", Composer.OPEN);
    } else {
      this.set("model.composeState", Composer.FULLSCREEN);
    }
  },

  close() {
    // the 'fullscreen-composer' class is added to remove scrollbars from the
    // document while in fullscreen mode. If the composer is closed for any reason
    // this class should be removed

    const elem = document.querySelector("html");
    elem.classList.remove("fullscreen-composer");
    elem.classList.remove("composer-open");

    document.activeElement && document.activeElement.blur();
    this.setProperties({ model: null, lastValidatedAt: null });
  },

  closeAutocomplete() {
    $(".d-editor-input").autocomplete({ cancel: true });
  },

  @discourseComputed("model.action")
  canEdit(modelAction) {
    return modelAction === "edit" && this.currentUser.can_edit;
  },

  @discourseComputed("model.composeState")
  visible(state) {
    return state && state !== "closed";
  },

  clearLastValidatedAt() {
    this.set("lastValidatedAt", null);
  },
});
