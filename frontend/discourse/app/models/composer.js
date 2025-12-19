import { tracked } from "@glimmer/tracking";
import EmberObject, { computed, set } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { next, throttle } from "@ember/runloop";
import { service } from "@ember/service";
import { isHTMLSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { observes, on } from "@ember-decorators/object";
import { Promise } from "rsvp";
import { extractError, throwAjaxError } from "discourse/lib/ajax-error";
import { tinyAvatar } from "discourse/lib/avatar-utils";
import deprecated from "discourse/lib/deprecated";
import { QUOTE_REGEXP } from "discourse/lib/quote";
import { prioritizeNameFallback } from "discourse/lib/settings";
import { applyValueTransformer } from "discourse/lib/transformer";
import { emailValid, escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import Draft from "discourse/models/draft";
import RestModel from "discourse/models/rest";
import Site from "discourse/models/site";
import Topic from "discourse/models/topic";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

let _customizations = [];

export function registerCustomizationCallback(cb) {
  _customizations.push(cb);
}

export function resetComposerCustomizations() {
  _customizations = [];
}

// The actions the composer can take
export const CREATE_TOPIC = "createTopic",
  CREATE_SHARED_DRAFT = "createSharedDraft",
  EDIT_SHARED_DRAFT = "editSharedDraft",
  PRIVATE_MESSAGE = "privateMessage",
  REPLY = "reply",
  EDIT = "edit",
  NEW_PRIVATE_MESSAGE_KEY = "new_private_message",
  NEW_TOPIC_KEY = "new_topic",
  EDIT_TOPIC_KEY = "topic_",
  ADD_TRANSLATION = "add_translation";

function isEdit(action) {
  return action === EDIT || action === EDIT_SHARED_DRAFT;
}

const CLOSED = "closed",
  SAVING = "saving",
  OPEN = "open",
  DRAFT = "draft",
  FULLSCREEN = "fullscreen",
  // When creating, these fields are moved into the post model from the composer model
  _create_serializer = {
    raw: "reply",
    title: "title",
    unlist_topic: "unlistTopic",
    category: "categoryId",
    topic_id: "topic.id",
    is_warning: "isWarning",
    whisper: "whisper",
    archetype: "archetypeId",
    target_recipients: "targetRecipients",
    typing_duration_msecs: "typingTime",
    composer_open_duration_msecs: "composerTime",
    composer_version: "composerVersion",
    tags: "tags",
    featured_link: "featuredLink",
    shared_draft: "creatingSharedDraft",
    no_bump: "noBump",
    draft_key: "draftKey",
    locale: "locale",
  },
  _update_serializer = {
    raw: "reply",
    topic_id: "topic.id",
    original_text: "originalText",
    locale: "locale",
  },
  _edit_topic_serializer = {
    title: "topic.title",
    categoryId: "topic.category.id",
    tags: "topic.tags",
    featuredLink: "topic.featured_link",
    original_title: "originalTitle",
    original_tags: "originalTags",
    locale: "locale",
  },
  _draft_serializer = {
    reply: "reply",
    action: "action",
    title: "title",
    categoryId: "categoryId",
    tags: "tags",
    archetypeId: "archetypeId",
    whisper: "whisper",
    metaData: "metaData",
    composerTime: "composerTime",
    typingTime: "typingTime",
    postId: "post.id",
    recipients: "targetRecipients",
    original_text: "originalText",
    original_title: "originalTitle",
    original_tags: "originalTags",
    locale: "locale",
  },
  _add_draft_fields = {},
  FAST_REPLY_LENGTH_THRESHOLD = 10000;

export const SAVE_LABELS = {
  [EDIT]: "composer.save_edit",
  [REPLY]: "composer.reply",
  [CREATE_TOPIC]: "composer.create_topic",
  [PRIVATE_MESSAGE]: "composer.create_pm",
  [CREATE_SHARED_DRAFT]: "composer.create_shared_draft",
  [EDIT_SHARED_DRAFT]: "composer.save_edit",
  [ADD_TRANSLATION]: "composer.translations.save",
};

export const SAVE_ICONS = {
  [EDIT]: "pencil",
  [EDIT_SHARED_DRAFT]: "far-clipboard",
  [REPLY]: "reply",
  [CREATE_TOPIC]: "plus",
  [PRIVATE_MESSAGE]: "envelope",
  [CREATE_SHARED_DRAFT]: "far-clipboard",
};

export default class Composer extends RestModel {
  // The status the compose view can have
  static CLOSED = CLOSED;
  static SAVING = SAVING;
  static OPEN = OPEN;
  static DRAFT = DRAFT;
  static FULLSCREEN = FULLSCREEN;

  // The actions the composer can take
  static CREATE_TOPIC = CREATE_TOPIC;
  static CREATE_SHARED_DRAFT = CREATE_SHARED_DRAFT;
  static EDIT_SHARED_DRAFT = EDIT_SHARED_DRAFT;
  static PRIVATE_MESSAGE = PRIVATE_MESSAGE;
  static REPLY = REPLY;
  static EDIT = EDIT;
  static ADD_TRANSLATION = ADD_TRANSLATION;

  // Draft key
  static NEW_PRIVATE_MESSAGE_KEY = NEW_PRIVATE_MESSAGE_KEY;
  static NEW_TOPIC_KEY = NEW_TOPIC_KEY;
  static EDIT_TOPIC_KEY = EDIT_TOPIC_KEY;

  // TODO: Replace with injection
  static create(args) {
    args = args || {};
    args.user = args.user || User.current();
    args.site = args.site || Site.current();
    return super.create(args);
  }

  static serializeToTopic(fieldName, property) {
    if (!property) {
      property = fieldName;
    }
    _edit_topic_serializer[fieldName] = property;
  }

  static serializeOnCreate(fieldName, property) {
    if (!property) {
      property = fieldName;
    }
    _create_serializer[fieldName] = property;
  }

  static serializedFieldsForCreate() {
    return Object.keys(_create_serializer);
  }

  static serializeOnUpdate(fieldName, property) {
    if (!property) {
      property = fieldName;
    }
    _update_serializer[fieldName] = property;
  }

  static serializedFieldsForUpdate() {
    return Object.keys(_update_serializer);
  }

  static serializeToDraft(fieldName, property) {
    if (!property) {
      property = fieldName;
    }
    _draft_serializer[fieldName] = property;
    _add_draft_fields[fieldName] = property;
  }

  static serializedFieldsForDraft() {
    return Object.keys(_draft_serializer);
  }

  @service dialog;
  @service siteSettings;
  @service currentUser;
  @service site;

  @tracked action;
  @tracked archetypeId;
  @tracked composeState;
  @tracked composerHeight;
  @tracked disableDrafts;
  @tracked draftKey;
  @tracked draftSaving = false;
  @tracked draftSequence;
  @tracked editConflict;
  @tracked featuredLink;
  @tracked loading;
  @tracked
  locale = this.siteSettings.content_localization_enabled
    ? this.post?.locale
    : null;
  @tracked metaData;
  @tracked originalTags;
  @tracked originalText;
  @tracked originalTitle;
  @tracked post;
  @tracked reply;
  @tracked showFullScreenExitPrompt = false;
  @tracked tags;
  @tracked targetRecipients;
  @tracked title;
  @tracked topic;
  @tracked whisper;

  unlistTopic = false;
  noBump = false;
  draftForceSave = false;

  @tracked _categoryId = null;

  @dependentKeyCompat
  get archetypes() {
    return this.site.archetypes;
  }

  @dependentKeyCompat
  get creatingTopic() {
    return this.action === CREATE_TOPIC;
  }

  @dependentKeyCompat
  get creatingSharedDraft() {
    return this.action === CREATE_SHARED_DRAFT;
  }

  @dependentKeyCompat
  get sharedDraft() {
    deprecated(
      "`composer.sharedDraft` is deprecated, use `composer.creatingSharedDraft` instead",
      {
        id: "discourse.replace-legacy-property.composer--sharedDraft",
        since: "2025.12.0",
        dropFrom: "2026.6.0",
      }
    );

    return this.creatingSharedDraft;
  }

  @dependentKeyCompat
  get creatingPrivateMessage() {
    return this.action === PRIVATE_MESSAGE;
  }

  @dependentKeyCompat
  get notCreatingPrivateMessage() {
    return !this.creatingPrivateMessage;
  }

  @dependentKeyCompat
  get notPrivateMessage() {
    return !this.privateMessage;
  }

  @dependentKeyCompat
  get topicFirstPost() {
    return this.creatingTopic || this.editingFirstPost;
  }

  @dependentKeyCompat
  get viewOpen() {
    return this.composeState === OPEN;
  }

  @dependentKeyCompat
  get viewDraft() {
    return this.composeState === DRAFT;
  }

  @dependentKeyCompat
  get viewFullscreen() {
    return this.composeState === FULLSCREEN;
  }

  @dependentKeyCompat
  get viewOpenOrFullscreen() {
    return this.viewOpen || this.viewFullscreen;
  }

  @dependentKeyCompat
  get editingFirstPost() {
    return this.editingPost && this.post?.firstPost;
  }

  @dependentKeyCompat
  get canEditTitle() {
    return (
      this.creatingTopic ||
      this.creatingPrivateMessage ||
      this.editingFirstPost ||
      this.creatingSharedDraft
    );
  }

  @dependentKeyCompat
  get canCategorize() {
    return (
      this.canEditTitle &&
      this.notCreatingPrivateMessage &&
      this.notPrivateMessage
    );
  }

  @dependentKeyCompat
  get replyDirty() {
    return (this.reply || "").trim() !== (this.originalText || "").trim();
  }

  @dependentKeyCompat
  get titleDirty() {
    return (this.title || "").trim() !== (this.originalTitle || "").trim();
  }

  @computed("replyDirty", "titleDirty", "hasMetaData")
  get anyDirty() {
    return this.replyDirty || this.titleDirty || this.hasMetaData;
  }

  @dependentKeyCompat
  get categoryId() {
    return this._categoryId;
  }

  // We wrap categoryId this way so we can fire `applyTopicTemplate` with
  // the previous value as well as the new value
  set categoryId(categoryId) {
    const oldCategoryId = this._categoryId;

    if (this.privateMessage) {
      categoryId = null;
    } else if (isEmpty(categoryId)) {
      // Check if there is a default composer category to set
      const defaultComposerCategoryId = parseInt(
        this.siteSettings.default_composer_category,
        10
      );
      categoryId =
        defaultComposerCategoryId && defaultComposerCategoryId > 0
          ? defaultComposerCategoryId
          : null;
    }
    this._categoryId = categoryId;

    if (oldCategoryId !== categoryId) {
      if (this.site.lazy_load_categories) {
        Category.asyncFindById(categoryId).then(() => {
          this.applyTopicTemplate(oldCategoryId, categoryId);
        });
      } else {
        this.applyTopicTemplate(oldCategoryId, categoryId);
      }
    }
  }

  @dependentKeyCompat
  get category() {
    return this.categoryId ? Category.findById(this.categoryId) : null;
  }

  @dependentKeyCompat
  get replyingToTopic() {
    return this.action === REPLY;
  }

  @dependentKeyCompat
  get editingPost() {
    return isEdit(this.action);
  }

  @computed("category.minimumRequiredTags")
  get minimumRequiredTags() {
    return this.get("category.minimumRequiredTags") || 0;
  }

  @computed("editingPost", "topic.details.can_edit")
  get disableTitleInput() {
    return this.editingPost && !this.get("topic.details.can_edit");
  }

  @computed("privateMessage", "archetype.hasOptions")
  get showCategoryChooser() {
    const manyCategories = this.site.categories.length > 1;
    return (
      !this.privateMessage &&
      (this.get("archetype.hasOptions") || manyCategories)
    );
  }

  @dependentKeyCompat
  get privateMessage() {
    return (
      this.creatingPrivateMessage ||
      (this.topic && this.topic.archetype === "private_message")
    );
  }

  @observes("composeState")
  composeStateChanged() {
    const oldOpen = this.composerOpened;
    const elem = document.documentElement;

    if (this.composeState === FULLSCREEN) {
      elem.classList.add("fullscreen-composer");
    } else {
      elem.classList.remove("fullscreen-composer");
    }

    if (this.composeState === OPEN) {
      this.set("composerOpened", oldOpen || new Date());
      elem.classList.add("composer-open");
    } else {
      if (oldOpen) {
        const oldTotal = this.composerTotalOpened || 0;
        this.set("composerTotalOpened", oldTotal + (new Date() - oldOpen));
      }
      this.set("composerOpened", null);
      elem.classList.remove("composer-open");
    }
  }

  get composerTime() {
    let total = this.composerTotalOpened || 0;
    const oldOpen = this.composerOpened;

    if (oldOpen) {
      total += new Date() - oldOpen;
    }

    return total;
  }

  get composerVersion() {
    if (this.siteSettings.rich_editor && this.currentUser.useRichEditor) {
      return 2;
    }

    return 1;
  }

  @dependentKeyCompat
  get archetype() {
    return this.archetypes.find(
      (archetype) => archetype.id === this.archetypeId
    );
  }

  @observes("archetype")
  archetypeChanged() {
    this.metaData = EmberObject.create();
  }

  // called whenever the user types to update the typing time
  typing() {
    throttle(
      this,
      function () {
        const typingTime = this.typingTime || 0;
        this.set("typingTime", typingTime + 100);
      },
      100,
      false
    );
  }

  @computed(
    "canEditTitle",
    "creatingPrivateMessage",
    "categoryId",
    "user.trust_level"
  )
  get canEditTopicFeaturedLink() {
    const userTrustLevel = this.get("user.trust_level");

    if (userTrustLevel === 0) {
      return false;
    }

    if (
      !this.siteSettings.topic_featured_link_enabled ||
      !this.canEditTitle ||
      this.creatingPrivateMessage
    ) {
      return false;
    }

    const categoryIds = this.site.topic_featured_link_allowed_category_ids;
    if (
      !this.categoryId &&
      categoryIds &&
      (categoryIds.includes(this.site.uncategorized_category_id) ||
        !this.siteSettings.allow_uncategorized_topics)
    ) {
      return true;
    }
    return (
      categoryIds === undefined ||
      !categoryIds.length ||
      categoryIds.includes(this.categoryId)
    );
  }

  @computed("canEditTopicFeaturedLink")
  get titlePlaceholder() {
    return this.canEditTopicFeaturedLink
      ? "composer.title_or_link_placeholder"
      : "composer.title_placeholder";
  }

  @dependentKeyCompat
  get replyOptions() {
    const options = {
      userLink: null,
      topicLink: null,
      postLink: null,
      userAvatar: null,
      originalUser: null,
    };

    if (this.topic) {
      options.topicLink = {
        href: this.topic.url,
        anchor:
          this.topic.fancyTitle || escapeExpression(this.get("topic.title")),
      };
    }

    if (this.post) {
      options.label = i18n(`post.${this.action}`);
      const avatarTemplate = applyValueTransformer(
        "composer-reply-options-user-avatar-template",
        this.post.avatar_template,
        { post: this.post }
      );
      options.userAvatar = tinyAvatar(avatarTemplate);

      if (this.site.desktopView) {
        const originalUserName = this.post.get("reply_to_user.username");
        const originalUserAvatar = this.post.get(
          "reply_to_user.avatar_template"
        );
        if (originalUserName && originalUserAvatar && isEdit(this.action)) {
          options.originalUser = {
            username: originalUserName,
            avatar: tinyAvatar(originalUserAvatar),
          };
        }
      }
    }

    if (this.topic && this.post) {
      const postNumber = this.post.post_number;

      options.postLink = {
        href: `${this.topic.url}/${postNumber}`,
        anchor: i18n("post.post_number", { number: postNumber }),
      };

      const namePrioritized = prioritizeNameFallback(
        this.post.name,
        this.post.username
      );
      const name = applyValueTransformer(
        "composer-reply-options-user-link-name",
        namePrioritized,
        { post: this.post }
      );

      options.userLink = {
        href: `${this.topic.url}/${postNumber}`,
        anchor: name,
      };
    }

    return options;
  }

  @dependentKeyCompat
  get targetRecipientsArray() {
    const recipients = this.targetRecipients
      ? this.targetRecipients.split(",")
      : [];
    const groups = new Set(this.site.groups.map((g) => g.name));

    return recipients.map((item) => {
      if (groups.has(item)) {
        return { type: "group", name: item };
      } else if (emailValid(item)) {
        return { type: "email", name: item };
      } else {
        return { type: "user", name: item };
      }
    });
  }

  @computed(
    "loading",
    "canEditTitle",
    "titleLength",
    "targetRecipients",
    "targetRecipientsArray",
    "replyLength",
    "categoryId",
    "missingReplyCharacters",
    "tags",
    "topicFirstPost",
    "minimumRequiredTags",
    "user.staff"
  )
  get cantSubmitPost() {
    // can't submit while loading
    if (this.loading) {
      return true;
    }

    // title is required when
    //  - creating a new topic/private message
    //  - editing the 1st post
    if (this.canEditTitle && !this.titleLengthValid) {
      return true;
    }

    // reply is always required
    if (this.missingReplyCharacters > 0) {
      return true;
    }

    if (
      this.site.can_tag_topics &&
      !this.get("user.staff") &&
      this.topicFirstPost &&
      this.minimumRequiredTags
    ) {
      const tagsArray = this.tags || [];
      if (tagsArray.length < this.minimumRequiredTags) {
        return true;
      }
    }

    if (this.topicFirstPost) {
      // user should modify topic template
      const category = this.category;
      if (category && category.topic_template) {
        if (this.reply.trim() === category.topic_template.trim()) {
          this.dialog.alert(i18n("composer.error.topic_template_not_modified"));
          return true;
        }
      }
    }

    if (this.privateMessage) {
      // need at least one user when sending a PM
      return this.targetRecipients && this.targetRecipientsArray.length === 0;
    } else {
      // has a category? (when needed)
      return this.requiredCategoryMissing;
    }
  }

  @computed("canCategorize", "categoryId")
  get requiredCategoryMissing() {
    return (
      this.canCategorize &&
      !this.categoryId &&
      !this.siteSettings.allow_uncategorized_topics &&
      !!this._hasTopicTemplates
    );
  }

  @computed("minimumTitleLength", "titleLength", "post.static_doc")
  get titleLengthValid() {
    const staticDoc = this.get("post.static_doc");
    if (this.user.admin && staticDoc && this.titleLength > 0) {
      return true;
    }
    if (this.titleLength < this.minimumTitleLength) {
      return false;
    }
    return this.titleLength <= this.siteSettings.max_topic_title_length;
  }

  @computed("metaData")
  get hasMetaData() {
    return this.metaData ? isEmpty(Object.keys(this.metaData)) : false;
  }

  @computed("minimumTitleLength", "titleLength")
  get missingTitleCharacters() {
    return this.minimumTitleLength - this.titleLength;
  }

  @computed("privateMessage")
  get minimumTitleLength() {
    if (this.privateMessage) {
      return this.siteSettings.min_personal_message_title_length;
    } else {
      return this.siteSettings.min_topic_title_length;
    }
  }

  @computed("minimumPostLength", "replyLength", "canEditTopicFeaturedLink")
  get missingReplyCharacters() {
    if (
      this.get("post.post_type") === this.site.get("post_types.small_action") ||
      (this.canEditTopicFeaturedLink && this.featuredLink)
    ) {
      return 0;
    }
    return this.minimumPostLength - this.replyLength;
  }

  @computed("privateMessage", "topicFirstPost", "topic.pm_with_non_human_user")
  get minimumPostLength() {
    const pmWithNonHumanUser = this.get("topic.pm_with_non_human_user");
    if (pmWithNonHumanUser) {
      return 1;
    } else if (this.privateMessage) {
      return this.siteSettings.min_personal_message_post_length;
    } else if (this.topicFirstPost) {
      // first post (topic body)
      return this.siteSettings.min_first_post_length;
    } else {
      return this.siteSettings.min_post_length;
    }
  }

  @dependentKeyCompat
  get titleLength() {
    let title = this.title || "";
    if (isHTMLSafe(title)) {
      return title.toString().length;
    }
    return title.replace(/\s+/gim, " ").trim().length;
  }

  @dependentKeyCompat
  get replyLength() {
    let reply = this.reply || "";

    if (reply.length > FAST_REPLY_LENGTH_THRESHOLD) {
      return reply.length;
    }

    const commentsRegexp = /<!--(.*?)-->/gm;
    while (commentsRegexp.test(reply)) {
      reply = reply.replace(commentsRegexp, "");
    }

    while (QUOTE_REGEXP.test(reply)) {
      // make it global so we can strip as many quotes at once
      // keep in mind nested quotes mean we still need a loop here
      const regex = new RegExp(QUOTE_REGEXP.source, "img");
      reply = reply.replace(regex, "");
    }

    // This is in place so we do not generate any intermediate
    // strings while calculating the length, this is issued
    // every keypress in the composer so it needs to be very fast
    let len = 0,
      skipSpace = true;

    for (let i = 0; i < reply.length; i++) {
      const code = reply.charCodeAt(i);

      let isSpace = false;
      if (code >= 0x2000 && code <= 0x200a) {
        isSpace = true;
      } else {
        switch (code) {
          case 0x09: // \t
          case 0x0a: // \n
          case 0x0b: // \v
          case 0x0c: // \f
          case 0x0d: // \r
          case 0x20:
          case 0xa0:
          case 0x1680:
          case 0x202f:
          case 0x205f:
          case 0x3000:
            isSpace = true;
        }
      }

      if (isSpace) {
        if (!skipSpace) {
          len++;
          skipSpace = true;
        }
      } else {
        len++;
        skipSpace = false;
      }
    }

    if (len > 0 && skipSpace) {
      len--;
    }

    return len;
  }

  @on("init")
  _setupComposer() {
    this.archetypeId = this.site.default_archetype;
  }

  appendText(text, position, opts) {
    const reply = this.reply || "";
    position = typeof position === "number" ? position : reply.length;

    let before = reply.slice(0, position) || "";
    let after = reply.slice(position) || "";

    let stripped, i;
    if (opts && opts.block) {
      if (before.trim() !== "") {
        stripped = before.replace(/\r/g, "");
        for (i = 0; i < 2; i++) {
          if (stripped[stripped.length - 1 - i] !== "\n") {
            before += "\n";
            position++;
          }
        }
      }
      if (after.trim() !== "") {
        stripped = after.replace(/\r/g, "");
        for (i = 0; i < 2; i++) {
          if (stripped[i] !== "\n") {
            after = "\n" + after;
          }
        }
      }
    }

    if (opts && opts.space) {
      if (before.length > 0 && !before[before.length - 1].match(/\s/)) {
        before = before + " ";
      }
      if (after.length > 0 && !after[0].match(/\s/)) {
        after = " " + after;
      }
    }

    if (opts && opts.new_line) {
      if (before.length > 0) {
        text = "\n\n" + text.trim();
      } else {
        text = text.trim();
      }
    }

    this.reply = before + text + after;

    return before.length + text.length;
  }

  prependText(text, opts) {
    const reply = this.reply || "";

    if (opts && opts.new_line && reply.length > 0) {
      text = text.trim() + "\n\n";
    }

    this.reply = text + reply;
  }

  applyTopicTemplate(oldCategoryId, categoryId) {
    if (this.action !== CREATE_TOPIC) {
      return;
    }

    let reply = this.reply;

    // If the user didn't change the template, clear it
    if (oldCategoryId) {
      const oldCat = Category.findById(oldCategoryId);
      if (oldCat && oldCat.topic_template === reply) {
        reply = "";
      }
    }

    if (!isEmpty(reply)) {
      return;
    }

    const category = Category.findById(categoryId);
    if (category) {
      this.reply = category.topic_template || "";
      this.originalText = category.topic_template || "";
    }
  }

  /**
   Open a composer

   @method open
   @param {Object} opts
   @param {String} opts.action The action we're performing: edit, reply, createTopic, createSharedDraft, privateMessage
   @param {String} opts.draftKey
   @param {String} opts.draftSequence
   @param {Post} [opts.post] The post we're replying to, if present
   @param {Topic} [opts.topic] The topic we're replying to, if present
   @param {String} [opts.quote] If we're opening a reply from a quote, the quote we're making
   @param {String} [opts.reply]
   @param {String} [opts.recipients]
   @param {Number} [opts.composerTime]
   @param {Number} [opts.typingTime]
   @param {Boolean} [opts.whisper]
   @param {Boolean} [opts.noBump]
   @param {String} [opts.archetypeId] One of `site.archetypes` e.g. `regular` or `private_message`
   @param {Object} [opts.metaData]
   @param {Number} [opts.categoryId]
   @param {Number} [opts.postId]
   @param {Number} [opts.destinationCategoryId]
   @param {String} [opts.title]
   **/
  open(opts) {
    let promise = Promise.resolve();

    if (!opts) {
      opts = {};
    }

    this.loading = true;

    if (
      !isEmpty(this.reply) &&
      (opts.reply || isEdit(opts.action)) &&
      this.replyDirty
    ) {
      return promise;
    }

    if (opts.action === REPLY && isEdit(this.action)) {
      this.reply = "";
    }

    if (!opts.draftKey) {
      throw new Error("draft key is required");
    }

    if (opts.draftSequence === null) {
      throw new Error("draft sequence is required");
    }

    if (opts.usernames) {
      deprecated("`usernames` is deprecated, use `recipients` instead.", {
        id: "discourse.composer.usernames",
      });
    }

    this.setProperties({
      draftKey: opts.draftKey,
      draftSequence: opts.draftSequence,
      composeState: opts.composerState || OPEN,
      action: opts.action,
      topic: opts.topic,
      targetRecipients: opts.usernames || opts.recipients,
      composerTotalOpened: opts.composerTime,
      typingTime: opts.typingTime,
      whisper: opts.whisper,
      tags: opts.tags || [],
      noBump: opts.noBump,
      originalText: opts.originalText,
      originalTitle: opts.originalTitle,
      originalTags: opts.originalTags,
    });

    if (opts.post) {
      this.setProperties({
        post: opts.post,
        whisper: opts.post.post_type === this.site.post_types.whisper,
      });

      if (!this.topic) {
        if (opts.post.topic) {
          this.topic = opts.post.topic;
        } else {
          // handles the edge cases where the topic model is not loaded in the post model and the store does not have a
          // topic for the post, e.g., make a post then edit right away, edit a post outside the post stream, etc.
          promise = promise.then(async () => {
            const data = await Topic.find(opts.post.topic_id, {});
            const topic = this.store.createRecord("topic", data);
            this.post.set("topic", topic);
            this.topic = topic;
          });
        }
      }
    } else if (opts.postId) {
      promise = promise.then(() =>
        this.store.find("post", opts.postId).then((post) => {
          this.post = post;
          if (post) {
            this.topic = post.topic;
          }
        })
      );
    } else {
      this.post = null;
    }

    this.setProperties({
      archetypeId: opts.archetypeId || this.site.default_archetype,
      metaData: opts.metaData ? EmberObject.create(opts.metaData) : null,
      reply: opts.reply || this.reply || "",
    });

    // We set the category id separately for topic templates on opening of composer
    if (!opts.readOnlyCategoryId) {
      this.set(
        "categoryId",
        opts.topicCategoryId || opts.categoryId || this.get("topic.category.id")
      );
    }

    if (!this.categoryId && this.creatingTopic) {
      const categories = this.site.categories;
      if (categories.length === 1) {
        this.set("categoryId", categories[0].id);
      }
    }

    this._hasTopicTemplates = this.site.categories.some(
      (c) => c.topic_template
    );

    // If we are editing a post, load it.
    if (isEdit(opts.action) && this.post) {
      const topicProps = this.serialize(_edit_topic_serializer);
      topicProps.loading = true;

      // When editing a shared draft, use its category
      if (opts.action === EDIT_SHARED_DRAFT && opts.destinationCategoryId) {
        topicProps.categoryId = opts.destinationCategoryId;
      }
      this.setProperties(topicProps);

      promise = promise.then(async () => {
        const post = await this.store.find("post", opts.post.id);
        this.setProperties({
          post,
          reply: post.raw,
          originalText: post.raw,
        });

        if (post.post_number === 1 && this.canEditTitle) {
          this.setProperties({
            originalTitle: this.topic.title,
            originalTags: this.topic.tags,
          });
        }

        this.appEvents.trigger("composer:reply-reloaded", this);
      });
    } else if (opts.action === REPLY && opts.quote) {
      this.reply = opts.quote;
      this.originalText = opts.quote;
    }

    if (opts.title) {
      this.title = opts.title;
    }

    if (this.canEditTitle) {
      if (isEmpty(this.title) && this.title !== "") {
        this.title = "";
      }
    }

    if (!isEdit(opts.action) || !opts.post) {
      promise = promise.then(() =>
        this.appEvents.trigger("composer:reply-reloaded", this)
      );
    }

    // Ensure additional draft fields are set
    Object.keys(_add_draft_fields).forEach((f) => {
      this.set(_add_draft_fields[f], opts[f]);
    });

    return promise.finally(() => {
      this.loading = false;
    });
  }

  // Overwrite to implement custom logic
  beforeSave() {
    return Promise.resolve();
  }

  save(opts) {
    return this.beforeSave().then(() => {
      if (!this.cantSubmitPost) {
        // change category may result in some effect for topic featured link
        if (!this.canEditTopicFeaturedLink) {
          this.featuredLink = null;
        }
        return this.editingPost ? this.editPost(opts) : this.createPost(opts);
      }
    });
  }

  clearState() {
    this.setProperties({
      originalText: null,
      originalTitle: null,
      originalTags: null,
      reply: null,
      post: null,
      title: null,
      unlistTopic: false,
      editReason: null,
      stagedPost: false,
      typingTime: 0,
      composerOpened: null,
      composerTotalOpened: 0,
      featuredLink: null,
      noBump: false,
      editConflict: false,
    });
  }

  editPost(opts) {
    this.composeState = SAVING;

    const post = this.post;
    const oldCooked = post.cooked;
    let promise = Promise.resolve();

    // Update the topic if we're editing the first post
    if (this.title && post.post_number === 1) {
      const topic = this.topic;

      if (topic.details.can_edit) {
        const topicProps = this.getProperties(
          Object.keys(_edit_topic_serializer)
        );
        // frontend should have featuredLink but backend needs featured_link
        if (topicProps.featuredLink) {
          topicProps.featured_link = topicProps.featuredLink;
          delete topicProps.featuredLink;
        }

        // If we're editing a shared draft, keep the original category
        if (this.action === EDIT_SHARED_DRAFT) {
          const destinationCategoryId = topicProps.categoryId;
          promise = promise.then(() =>
            topic.updateDestinationCategory(destinationCategoryId)
          );
          topicProps.categoryId = topic.get("category.id");
        }
        promise = promise.then(() => Topic.update(topic, topicProps));
      } else if (topic.details.can_edit_tags) {
        promise = promise.then(() => topic.updateTags(this.tags));
      }
    }

    let props = {
      edit_reason: opts.editReason,
      image_sizes: opts.imageSizes,
    };

    this.serialize(_update_serializer, props);

    // user clicked "overwrite edits" button
    if (this.editConflict) {
      delete props.original_text;
      delete props.original_title;
      delete props.original_tags;
    }

    const rollback = throwAjaxError((error) => {
      post.setProperties("cooked", oldCooked);
      this.composeState = OPEN;
      if (error.jqXHR && error.jqXHR.status === 409) {
        this.editConflict = true;
      }
    });

    const cooked = this.getCookedHtml();
    post.setProperties({ cooked, staged: true });

    return promise
      .then(() => {
        return post.save(props).then((result) => {
          this.clearState();
          return result;
        });
      })
      .catch(rollback)
      .finally(() => {
        post.set("staged", false);
      });
  }

  serialize(serializer, dest) {
    dest = dest || {};
    Object.keys(serializer).forEach((f) => {
      const val = this.get(serializer[f]);
      if (typeof val !== "undefined") {
        set(dest, f, val);
      }
    });
    return dest;
  }

  async createPost(opts) {
    if (CREATE_TOPIC === this.action || PRIVATE_MESSAGE === this.action) {
      this.topic = null;
    }

    const post = this.post;
    const topic = this.topic;
    const user = this.user;
    const postStream = this.get("topic.postStream");
    const postTypes = this.site.post_types;
    const postType = this.whisper ? postTypes.whisper : postTypes.regular;

    // Build the post object
    const createdPost = this.store.createRecord("post", {
      imageSizes: opts.imageSizes,
      cooked: this.getCookedHtml(),
      reply_count: 0,
      name: user.name,
      display_username: user.name,
      username: user.username,
      user_id: user.id,
      user_title: user.title,
      avatar_template: user.avatar_template,
      user_custom_fields: user.custom_fields,
      post_type: postType,
      actions_summary: [],
      moderator: user.moderator,
      admin: user.admin,
      yours: true,
      read: true,
      wiki: false,
      typingTime: this.typingTime,
      composerTime: this.composerTime,
      metaData: this.metaData,
      locale: this.siteSettings.content_localization_enabled
        ? this.locale
        : null,
    });

    this.serialize(_create_serializer, createdPost);

    if (post) {
      createdPost.setProperties({
        reply_to_post_number: post.post_number,
        reply_to_user: post.getProperties("username", "avatar_template"),
      });
    }

    let state = null;

    // If we're in a topic, we can append the post instantly.
    if (postStream) {
      // If it's in reply to another post, increase the reply count
      post?.setProperties({
        reply_count: (post.reply_count || 0) + 1,
        replies: [],
      });

      // We do not stage posts in mobile view, we do not have the "cooked"
      // Furthermore calculating cooked is very complicated, especially since
      // we would need to handle oneboxes and other bits that are not even in the
      // engine, staging will just cause a blank post to render
      if (!isEmpty(createdPost.cooked)) {
        state = postStream.stagePost(createdPost, user);
        if (state === "alreadyStaging") {
          return;
        }
      }
    }

    this.setProperties({
      composeState: SAVING,
      stagedPost: state === "staged" && createdPost,
    });

    try {
      const result = await createdPost.save();
      let saving = true;

      if (result.responseJson.action === "enqueued") {
        postStream?.undoPost(createdPost);
        return result;
      }

      // We sometimes want to hide the `reply_to_user` if the post contains a quote
      if (result.responseJson.post && !result.responseJson.post.reply_to_user) {
        createdPost.set("reply_to_user", null);
      }

      let addedToStream = false;
      if (topic) {
        // It's no longer a new post
        topic.set("draft_sequence", result.target.draft_sequence);
        postStream.commitPost(createdPost);
        addedToStream = true;
      } else {
        // We created a new topic, let's show it.
        this.composeState = CLOSED;
        saving = false;

        // Update topic_count for the category
        const postCategoryId = parseInt(createdPost.category, 10) || 1;
        const category = Category.findById(postCategoryId);

        category?.incrementProperty("topic_count");
      }

      this.clearState();
      this.set("createdPost", createdPost);

      if (this.replyingToTopic) {
        this.appEvents.trigger("post:created", createdPost);
      } else {
        this.appEvents.trigger("topic:created", createdPost, this);
      }

      if (addedToStream) {
        this.composeState = CLOSED;
      } else if (saving) {
        this.composeState = SAVING;
      }

      return result;
    } catch (error) {
      if (postStream) {
        postStream.undoPost(createdPost);

        post?.set("reply_count", post.reply_count - 1);
      }

      next(() => (this.composeState = OPEN));

      throw extractError(error);
    }
  }

  getCookedHtml() {
    const editorPreviewNode = document.querySelector(
      "#reply-control .d-editor-preview"
    );

    if (editorPreviewNode) {
      return editorPreviewNode.innerHTML.replace(
        /<span class="marker"><\/span>/g,
        ""
      );
    }

    return "";
  }

  @computed(
    "draftSaving",
    "disableDrafts",
    "canEditTitle",
    "title",
    "reply",
    "titleLengthValid",
    "replyLength",
    "minimumPostLength"
  )
  get canSaveDraft() {
    if (this.action === Composer.ADD_TRANSLATION) {
      return false;
    }

    if (this.draftSaving) {
      return false;
    }

    if (this.disableDrafts) {
      return false;
    }

    // Title is only edited when editing topic OP or making a new topic.
    if (this.canEditTitle) {
      if (isEmpty(this.title) && isEmpty(this.reply)) {
        return false;
      }
    } else {
      if (isEmpty(this.reply)) {
        return false;
      }
    }

    return true;
  }

  saveDraft() {
    if (!this.canSaveDraft) {
      return Promise.reject();
    }

    this.draftSaving = true;

    const data = this.serialize(_draft_serializer);

    const draftSequence = this.draftSequence;
    this.draftSequence = this.draftSequence + 1;

    return Draft.save(
      this.draftKey,
      draftSequence,
      data,
      this.messageBus.clientId,
      { forceSave: this.draftForceSave }
    )
      .then((result) => {
        if ("draft_sequence" in result) {
          this.draftSequence = result.draft_sequence;
        }
        if (result.conflict_user) {
          this.setProperties({
            draftStatus: i18n("composer.edit_conflict"),
            draftConflictUser: result.conflict_user,
          });
        } else {
          this.setProperties({
            draftStatus: null,
            draftConflictUser: null,
            draftForceSave: false,
          });
        }

        return result;
      })
      .catch((e) => {
        let draftStatus;
        const xhr = e && e.jqXHR;

        if (
          xhr &&
          xhr.status === 409 &&
          xhr.responseJSON &&
          xhr.responseJSON.errors &&
          xhr.responseJSON.errors.length
        ) {
          const json = e.jqXHR.responseJSON;
          draftStatus = json.errors[0];

          if (json.extras?.description) {
            this.dialog.alert({
              message: json.extras.description,
              buttons: [
                {
                  label: i18n("composer.reload"),
                  class: "btn-primary",
                  action: () => window.location.reload(),
                },
                {
                  label: i18n("composer.ignore"),
                  class: "btn-default",
                  action: () => this.set("draftForceSave", true),
                },
              ],
            });
          }
        }
        this.setProperties({
          draftStatus: draftStatus || i18n("composer.drafts_offline"),
          draftConflictUser: null,
        });
      })
      .finally(() => {
        this.draftSaving = false;
      });
  }

  customizationFor(type) {
    for (let i = 0; i < _customizations.length; i++) {
      let cb = _customizations[i][type];
      if (cb) {
        let result = cb(this);
        if (result) {
          return result;
        }
      }
    }
  }
}
