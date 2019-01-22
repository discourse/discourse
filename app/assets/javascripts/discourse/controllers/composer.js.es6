import DiscourseURL from "discourse/lib/url";
import Quote from "discourse/lib/quote";
import Draft from "discourse/models/draft";
import Composer from "discourse/models/composer";
import {
  default as computed,
  observes,
  on
} from "ember-addons/ember-computed-decorators";
import InputValidation from "discourse/models/input-validation";
import { getOwner } from "discourse-common/lib/get-owner";
import {
  escapeExpression,
  uploadIcon,
  authorizesOneOrMoreExtensions
} from "discourse/lib/utilities";
import { emojiUnescape } from "discourse/lib/text";
import { shortDate } from "discourse/lib/formatter";
import { SAVE_LABELS, SAVE_ICONS } from "discourse/models/composer";

function loadDraft(store, opts) {
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
    composer.open({
      draftKey,
      draftSequence,
      action: draft.action,
      title: draft.title,
      categoryId: draft.categoryId || opts.categoryId,
      postId: draft.postId,
      archetypeId: draft.archetypeId,
      reply: draft.reply,
      metaData: draft.metaData,
      usernames: draft.usernames,
      draft: true,
      composerState: Composer.DRAFT,
      composerTime: draft.composerTime,
      typingTime: draft.typingTime,
      whisper: draft.whisper,
      tags: draft.tags,
      noBump: draft.noBump
    });
    return composer;
  }
}

const _popupMenuOptionsCallbacks = [];

let _checkDraftPopup = !Ember.testing;

export function toggleCheckDraftPopup(enabled) {
  _checkDraftPopup = enabled;
}

export function clearPopupMenuOptionsCallback() {
  _popupMenuOptionsCallbacks.length = 0;
}

export function addPopupMenuOptionsCallback(callback) {
  _popupMenuOptionsCallbacks.push(callback);
}

export default Ember.Controller.extend({
  topicController: Ember.inject.controller("topic"),
  application: Ember.inject.controller(),

  replyAsNewTopicDraft: Ember.computed.equal(
    "model.draftKey",
    Composer.REPLY_AS_NEW_TOPIC_KEY
  ),
  replyAsNewPrivateMessageDraft: Ember.computed.equal(
    "model.draftKey",
    Composer.REPLY_AS_NEW_PRIVATE_MESSAGE_KEY
  ),
  checkedMessages: false,
  messageCount: null,
  showEditReason: false,
  editReason: null,
  scopedCategoryId: null,
  lastValidatedAt: null,
  isUploading: false,
  allowUpload: false,
  uploadIcon: "upload",
  topic: null,
  linkLookup: null,
  showPreview: true,
  forcePreview: Ember.computed.and("site.mobileView", "showPreview"),
  whisperOrUnlistTopic: Ember.computed.or("isWhispering", "model.unlistTopic"),
  categories: Ember.computed.alias("site.categoriesList"),

  @on("init")
  _setupPreview() {
    const val = this.site.mobileView
      ? false
      : this.keyValueStore.get("composer.showPreview") || "true";
    this.set("showPreview", val === "true");
  },

  @computed("showPreview")
  toggleText: function(showPreview) {
    return showPreview
      ? I18n.t("composer.hide_preview")
      : I18n.t("composer.show_preview");
  },

  @observes("showPreview")
  showPreviewChanged() {
    if (!this.site.mobileView) {
      this.keyValueStore.set({
        key: "composer.showPreview",
        value: this.get("showPreview")
      });
    }
  },

  @computed(
    "model.replyingToTopic",
    "model.creatingPrivateMessage",
    "model.targetUsernames"
  )
  focusTarget(replyingToTopic, creatingPM, usernames) {
    if (this.capabilities.isIOS) {
      return "none";
    }

    // Focus on usernames if it's blank or if it's just you
    usernames = usernames || "";
    if (
      (creatingPM && usernames.length === 0) ||
      usernames === this.currentUser.get("username")
    ) {
      return "usernames";
    }

    if (replyingToTopic) {
      return "reply";
    }

    return "title";
  },

  showToolbar: Ember.computed({
    get() {
      const keyValueStore = getOwner(this).lookup("key-value-store:main");
      const storedVal = keyValueStore.get("toolbar-enabled");
      if (this._toolbarEnabled === undefined && storedVal === undefined) {
        // iPhone 6 is 375, anything narrower and toolbar should
        // be default disabled.
        // That said we should remember the state
        this._toolbarEnabled =
          $(window).width() > 370 && !this.capabilities.isAndroid;
      }
      return this._toolbarEnabled || storedVal === "true";
    },
    set(key, val) {
      const keyValueStore = getOwner(this).lookup("key-value-store:main");
      this._toolbarEnabled = val;
      keyValueStore.set({
        key: "toolbar-enabled",
        value: val ? "true" : "false"
      });
      return val;
    }
  }),

  topicModel: Ember.computed.alias("topicController.model"),

  @computed("model.canEditTitle", "model.creatingPrivateMessage")
  canEditTags(canEditTitle, creatingPrivateMessage) {
    return (
      this.site.get("can_tag_topics") &&
      canEditTitle &&
      !creatingPrivateMessage &&
      (!this.get("model.topic.isPrivateMessage") ||
        this.site.get("can_tag_pms"))
    );
  },

  @computed
  isStaffUser() {
    const currentUser = this.currentUser;
    return currentUser && currentUser.get("staff");
  },

  canUnlistTopic: Ember.computed.and("model.creatingTopic", "isStaffUser"),

  @computed("canWhisper", "replyingToWhisper")
  showWhisperToggle(canWhisper, replyingToWhisper) {
    return canWhisper && !replyingToWhisper;
  },

  @computed("model.post")
  replyingToWhisper(repliedToPost) {
    return (
      repliedToPost &&
      repliedToPost.get("post_type") === this.site.post_types.whisper
    );
  },

  @computed("replyingToWhisper", "model.whisper")
  isWhispering(replyingToWhisper, whisper) {
    return replyingToWhisper || whisper;
  },

  @computed("model.action", "isWhispering")
  saveIcon(action, isWhispering) {
    if (isWhispering) {
      return "far-eye-slash";
    }
    return SAVE_ICONS[action];
  },

  @computed("model.action", "isWhispering", "model.editConflict")
  saveLabel(action, isWhispering, editConflict) {
    if (editConflict) {
      return "composer.overwrite_edit";
    } else if (isWhispering) {
      return "composer.create_whisper";
    }
    return SAVE_LABELS[action];
  },

  @computed("isStaffUser", "model.action")
  canWhisper(isStaffUser, action) {
    return (
      this.siteSettings.enable_whispers &&
      isStaffUser &&
      Composer.REPLY === action
    );
  },

  _setupPopupMenuOption(callback) {
    let option = callback();

    if (option.condition) {
      option.condition = this.get(option.condition);
    } else {
      option.condition = true;
    }

    return option;
  },

  @computed("model.composeState", "model.creatingTopic", "model.post")
  popupMenuOptions(composeState) {
    if (composeState === "open" || composeState === "fullscreen") {
      let options = [];

      options.push(
        this._setupPopupMenuOption(() => {
          return {
            action: "toggleInvisible",
            icon: "far-eye-slash",
            label: "composer.toggle_unlisted",
            condition: "canUnlistTopic"
          };
        })
      );

      options.push(
        this._setupPopupMenuOption(() => {
          return {
            action: "toggleWhisper",
            icon: "far-eye-slash",
            label: "composer.toggle_whisper",
            condition: "showWhisperToggle"
          };
        })
      );

      return options.concat(
        _popupMenuOptionsCallbacks.map(callback => {
          return this._setupPopupMenuOption(callback);
        })
      );
    }
  },

  showWarning: function() {
    if (!Discourse.User.currentProp("staff")) {
      return false;
    }

    var usernames = this.get("model.targetUsernames");
    var hasTargetGroups = this.get("model.hasTargetGroups");

    // We need exactly one user to issue a warning
    if (
      Ember.isEmpty(usernames) ||
      usernames.split(",").length !== 1 ||
      hasTargetGroups
    ) {
      return false;
    }
    return this.get("model.creatingPrivateMessage");
  }.property("model.creatingPrivateMessage", "model.targetUsernames"),

  @computed("model.topic")
  draftTitle(topic) {
    return emojiUnescape(escapeExpression(topic.get("title")));
  },

  @computed
  allowUpload() {
    return authorizesOneOrMoreExtensions();
  },

  @computed()
  uploadIcon: () => uploadIcon(),

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
        if (post) url = post.get("url");
        if (!post && topic) url = topic.get("url");

        let topicTitle;
        if (topic) topicTitle = topic.get("title");

        if (!url || !topicTitle) return;

        url = `${location.protocol}//${location.host}${url}`;
        const link = `[${Handlebars.escapeExpression(topicTitle)}](${url})`;
        const continueDiscussion = I18n.t("post.continue_discussion", {
          postLink: link
        });

        const reply = this.get("model.reply");
        if (!reply || !reply.includes(continueDiscussion)) {
          this.get("model").prependText(continueDiscussion, {
            new_line: true
          });
        }
      });
    },

    cancelUpload() {
      this.set("model.uploadCancelled", true);
    },

    onPopupMenuAction(action) {
      this.send(action);
    },

    storeToolbarState(toolbarEvent) {
      this.set("toolbarEvent", toolbarEvent);
    },

    typed() {
      this.checkReplyLength();
      this.get("model").typing();
    },

    cancelled() {
      this.send("hitEsc");
    },

    addLinkLookup(linkLookup) {
      this.set("linkLookup", linkLookup);
    },

    afterRefresh($preview) {
      const topic = this.get("model.topic");
      const linkLookup = this.get("linkLookup");
      if (!topic || !linkLookup) {
        return;
      }

      // Don't check if there's only one post
      if (topic.get("posts_count") === 1) {
        return;
      }

      const post = this.get("model.post");
      const $links = $("a[href]", $preview);
      $links.each((idx, l) => {
        const href = $(l).prop("href");
        if (href && href.length) {
          const [warn, info] = linkLookup.check(post, href);

          if (warn) {
            const body = I18n.t("composer.duplicate_link", {
              domain: info.domain,
              username: info.username,
              post_url: topic.urlForPostNumber(info.post_number),
              ago: shortDate(info.posted_at)
            });
            this.appEvents.trigger("composer-messages:create", {
              extraClass: "custom-body",
              templateName: "custom-body",
              body
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
        Ember.isEmpty(this.get("model.reply")) &&
        Ember.isEmpty(this.get("model.title"))
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
          const replyPost = postStream
            .get("posts")
            .findBy("post_number", replyToPostNumber);
          if (replyPost) {
            postId = replyPost.get("id");
          }
        }
      }

      if (postId) {
        this.set("model.loading", true);
        const composer = this;

        return this.store.find("post", postId).then(function(post) {
          const quote = Quote.build(post, post.get("raw"), {
            raw: true,
            full: true
          });
          toolbarEvent.addText(quote);
          composer.set("model.loading", false);
        });
      }
    },

    cancel() {
      this.cancelComposer();
    },

    save() {
      this.save();
    },

    displayEditReason() {
      this.set("showEditReason", true);
    },

    hitEsc() {
      if (Ember.$(".emoji-picker-modal.fadeIn").length === 1) {
        this.appEvents.trigger("emoji-picker:close");
        return;
      }

      if ((this.get("messageCount") || 0) > 0) {
        this.appEvents.trigger("composer-messages:close");
        return;
      }

      if (this.get("model.viewOpen") || this.get("model.viewFullscreen")) {
        this.shrink();
      }
    },

    openIfDraft() {
      if (this.get("model.viewDraft")) {
        this.set("model.composeState", Composer.OPEN);
      }
    },

    groupsMentioned(groups) {
      if (
        !this.get("model.creatingPrivateMessage") &&
        !this.get("model.topic.isPrivateMessage")
      ) {
        groups.forEach(group => {
          let body;

          if (group.max_mentions < group.user_count) {
            body = I18n.t("composer.group_mentioned_limit", {
              group: "@" + group.name,
              max: group.max_mentions,
              group_link: Discourse.getURL(`/groups/${group.name}/members`)
            });
          } else {
            body = I18n.t("composer.group_mentioned", {
              group: "@" + group.name,
              count: group.user_count,
              group_link: Discourse.getURL(`/groups/${group.name}/members`)
            });
          }

          this.appEvents.trigger("composer-messages:create", {
            extraClass: "custom-body",
            templateName: "custom-body",
            body
          });
        });
      }
    },

    cannotSeeMention(mentions) {
      mentions.forEach(mention => {
        const translation = this.get("model.topic.isPrivateMessage")
          ? "composer.cannot_see_mention.private"
          : "composer.cannot_see_mention.category";
        const body = I18n.t(translation, {
          username: "@" + mention.name
        });
        this.appEvents.trigger("composer-messages:create", {
          extraClass: "custom-body",
          templateName: "custom-body",
          body
        });
      });
    }
  },

  disableSubmit: Ember.computed.or("model.loading", "isUploading"),

  save(force) {
    if (this.get("disableSubmit")) return;

    // Clear the warning state if we're not showing the checkbox anymore
    if (!this.get("showWarning")) {
      this.set("model.isWarning", false);
    }

    const composer = this.get("model");

    if (composer.get("cantSubmitPost")) {
      this.set("lastValidatedAt", Date.now());
      return;
    }

    composer.set("disableDrafts", true);

    // for now handle a very narrow use case
    // if we are replying to a topic AND not on the topic pop the window up
    if (!force && composer.get("replyingToTopic")) {
      const currentTopic = this.get("topicModel");

      if (!currentTopic) {
        this.save(true);
        return;
      }

      if (currentTopic.get("id") !== composer.get("topic.id")) {
        const message = I18n.t("composer.posting_not_on_topic");

        let buttons = [
          {
            label: I18n.t("composer.cancel"),
            class: "d-modal-cancel",
            link: true
          }
        ];

        buttons.push({
          label:
            I18n.t("composer.reply_here") +
            "<br/><div class='topic-title overflow-ellipsis'>" +
            currentTopic.get("fancyTitle") +
            "</div>",
          class: "btn btn-reply-here",
          callback: () => {
            composer.set("topic", currentTopic);
            composer.set("post", null);
            this.save(true);
          }
        });

        buttons.push({
          label:
            I18n.t("composer.reply_original") +
            "<br/><div class='topic-title overflow-ellipsis'>" +
            this.get("model.topic.fancyTitle") +
            "</div>",
          class: "btn-primary btn-reply-on-original",
          callback: () => this.save(true)
        });

        bootbox.dialog(message, buttons, { classes: "reply-where-modal" });
        return;
      }
    }

    var staged = false;

    // TODO: This should not happen in model
    const imageSizes = {};
    $("#reply-control .d-editor-preview img").each((i, e) => {
      const $img = $(e);
      const src = $img.prop("src");

      if (src && src.length) {
        imageSizes[src] = { width: $img.width(), height: $img.height() };
      }
    });

    const promise = composer
      .save({ imageSizes, editReason: this.get("editReason") })
      .then(result => {
        if (result.responseJson.action === "enqueued") {
          this.send("postWasEnqueued", result.responseJson);
          this.destroyDraft();
          this.close();
          this.appEvents.trigger("post-stream:refresh");
          return result;
        }

        // If user "created a new topic/post" or "replied as a new topic" successfully, remove the draft.
        if (
          result.responseJson.action === "create_post" ||
          this.get("replyAsNewTopicDraft") ||
          this.get("replyAsNewPrivateMessageDraft")
        ) {
          this.destroyDraft();
        }
        if (this.get("model.editingPost")) {
          this.appEvents.trigger("post-stream:refresh", {
            id: parseInt(result.responseJson.id)
          });
          if (result.responseJson.post.post_number === 1) {
            this.appEvents.trigger(
              "header:update-topic",
              composer.get("topic")
            );
          }
        } else {
          this.appEvents.trigger("post-stream:refresh");
        }

        if (result.responseJson.action === "create_post") {
          this.appEvents.trigger("post:highlight", result.payload.post_number);
        }
        this.close();

        const currentUser = Discourse.User.current();
        if (composer.get("creatingTopic")) {
          currentUser.set("topic_count", currentUser.get("topic_count") + 1);
        } else {
          currentUser.set("reply_count", currentUser.get("reply_count") + 1);
        }

        const disableJumpReply = Discourse.User.currentProp(
          "disable_jump_reply"
        );
        if (!composer.get("replyingToTopic") || !disableJumpReply) {
          const post = result.target;
          if (post && !staged) {
            DiscourseURL.routeTo(post.get("url"));
          }
        }
      })
      .catch(error => {
        composer.set("disableDrafts", false);
        this.appEvents.one("composer:will-open", () => bootbox.alert(error));
      });

    if (
      this.get("application.currentRouteName").split(".")[0] === "topic" &&
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
    if (!Ember.isEmpty("model.reply")) {
      this.appEvents.trigger("composer:typed-reply");
    }
  },

  /**
    Open the composer view

    @method open
    @param {Object} opts Options for creating a post
      @param {String} opts.action The action we're performing: edit, reply or createTopic
      @param {Discourse.Post} [opts.post] The post we're replying to
      @param {Discourse.Topic} [opts.topic] The topic we're replying to
      @param {String} [opts.quote] If we're opening a reply from a quote, the quote we're making
  **/
  open(opts) {
    opts = opts || {};

    if (!opts.draftKey) {
      throw new Error("composer opened without a proper draft key");
    }

    const self = this;
    let composerModel = this.get("model");

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
      scopedCategoryId: null
    });

    // Scope the categories drop down to the category we opened the composer with.
    if (opts.categoryId && opts.draftKey !== "reply_as_new_topic") {
      const category = this.site.categories.findBy("id", opts.categoryId);
      if (category) {
        this.set("scopedCategoryId", opts.categoryId);
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

    return new Ember.RSVP.Promise(function(resolve, reject) {
      if (composerModel && composerModel.get("replyDirty")) {
        // If we're already open, we don't have to do anything
        if (
          composerModel.get("composeState") === Composer.OPEN &&
          composerModel.get("draftKey") === opts.draftKey &&
          !opts.action
        ) {
          return resolve();
        }

        // If it's the same draft, just open it up again.
        if (
          composerModel.get("composeState") === Composer.DRAFT &&
          composerModel.get("draftKey") === opts.draftKey
        ) {
          composerModel.set("composeState", Composer.OPEN);
          if (!opts.action) return resolve();
        }

        // If it's a different draft, cancel it and try opening again.
        return self
          .cancelComposer()
          .then(function() {
            return self.open(opts);
          })
          .then(resolve, reject);
      }

      if (composerModel) {
        if (composerModel.get("action") !== opts.action) {
          composerModel.setProperties({ unlistTopic: false, whisper: false });
        }
      }

      // we need a draft sequence for the composer to work
      if (opts.draftSequence === undefined) {
        return Draft.get(opts.draftKey)
          .then(data => {
            if (opts.skipDraftCheck) {
              data.draft = undefined;
              return data;
            }

            return self.confirmDraftAbandon(data);
          })
          .then(data => {
            if (!opts.draft && data.draft) {
              opts.draft = data.draft;
            }
            opts.draftSequence = data.draft_sequence;
            self._setModel(composerModel, opts);
          })
          .then(resolve, reject);
      }
      // otherwise, do the draft check async
      else if (!opts.draft && !opts.skipDraftCheck) {
        Draft.get(opts.draftKey)
          .then(data => self.confirmDraftAbandon(data))
          .then(data => {
            if (data.draft) {
              opts.draft = data.draft;
              opts.draftSequence = data.draft_sequence;
              self.open(opts);
            }
          });
      }

      self._setModel(composerModel, opts);
      resolve();
    });
  },

  // Given a potential instance and options, set the model for this composer.
  _setModel(composerModel, opts) {
    this.set("linkLookup", null);

    if (opts.draft) {
      composerModel = loadDraft(this.store, opts);
      if (composerModel) {
        composerModel.set("topic", opts.topic);
      }
    } else {
      composerModel = composerModel || this.store.createRecord("composer");
      composerModel.open(opts);
    }

    this.set("model", composerModel);
    composerModel.set("composeState", Composer.OPEN);
    composerModel.set("isWarning", false);

    if (opts.usernames) {
      this.set("model.targetUsernames", opts.usernames);
    }

    if (
      opts.topicTitle &&
      opts.topicTitle.length <= this.siteSettings.max_topic_title_length
    ) {
      this.set("model.title", escapeExpression(opts.topicTitle));
    }

    if (opts.topicCategoryId) {
      this.set("model.categoryId", opts.topicCategoryId);
    }

    if (
      opts.topicTags &&
      !this.site.mobileView &&
      this.site.get("can_tag_topics")
    ) {
      const self = this;
      let tags = escapeExpression(opts.topicTags)
        .split(",")
        .slice(0, self.siteSettings.max_tags_per_topic);
      tags.forEach(function(tag, index, array) {
        array[index] = tag.substring(0, self.siteSettings.max_tag_length);
      });
      self.set("model.tags", tags);
    }

    if (opts.topicBody) {
      this.set("model.reply", opts.topicBody);
    }
  },

  // View a new reply we've made
  viewNewReply() {
    DiscourseURL.routeTo(this.get("model.createdPost.url"));
    this.close();
    return false;
  },

  destroyDraft() {
    const key = this.get("model.draftKey");
    if (key) {
      if (key === "new_topic") {
        this.send("clearTopicDraft");
      }

      Draft.clear(key, this.get("model.draftSequence")).then(() => {
        this.appEvents.trigger("draft:destroyed", key);
      });
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
      return new Ember.RSVP.Promise(resolve => {
        bootbox.dialog(I18n.t("drafts.abandon.confirm"), [
          {
            label: I18n.t("drafts.abandon.no_value"),
            callback: () => resolve(data)
          },
          {
            label: I18n.t("drafts.abandon.yes_value"),
            class: "btn-danger",
            callback: () => {
              data.draft = null;
              resolve(data);
            }
          }
        ]);
      });
    } else {
      data.draft = null;
      return data;
    }
  },

  cancelComposer() {
    return new Ember.RSVP.Promise(resolve => {
      if (this.get("model.hasMetaData") || this.get("model.replyDirty")) {
        bootbox.dialog(I18n.t("post.abandon.confirm"), [
          { label: I18n.t("post.abandon.no_value") },
          {
            label: I18n.t("post.abandon.yes_value"),
            class: "btn-danger",
            callback: result => {
              if (result) {
                this.destroyDraft();
                this.get("model").clearState();
                this.close();
                resolve();
              }
            }
          }
        ]);
      } else {
        // it is possible there is some sort of crazy draft with no body ... just give up on it
        this.destroyDraft();
        this.get("model").clearState();
        this.close();
        resolve();
      }
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
    const model = this.get("model");
    if (model) {
      model.saveDraft();
    }
  },

  @observes("model.reply", "model.title")
  _shouldSaveDraft() {
    Ember.run.debounce(this, this._saveDraft, 2000);
  },

  @computed("model.categoryId", "lastValidatedAt")
  categoryValidation(categoryId, lastValidatedAt) {
    if (!this.siteSettings.allow_uncategorized_topics && !categoryId) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t("composer.error.category_missing"),
        lastShownAt: lastValidatedAt
      });
    }
  },

  @computed("model.category", "model.tags", "lastValidatedAt")
  tagValidation(category, tags, lastValidatedAt) {
    const tagsArray = tags || [];
    if (
      this.site.get("can_tag_topics") &&
      category &&
      category.get("minimum_required_tags") > tagsArray.length
    ) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t("composer.error.tags_missing", {
          count: category.get("minimum_required_tags")
        }),
        lastShownAt: lastValidatedAt
      });
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
    $("html").removeClass("fullscreen-composer");
    this.setProperties({ model: null, lastValidatedAt: null });
  },

  closeAutocomplete() {
    $(".d-editor-input").autocomplete({ cancel: true });
  },

  canEdit: function() {
    return (
      this.get("model.action") === "edit" &&
      Discourse.User.current().get("can_edit")
    );
  }.property("model.action"),

  visible: function() {
    var state = this.get("model.composeState");
    return state && state !== "closed";
  }.property("model.composeState")
});
