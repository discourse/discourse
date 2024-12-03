import { tracked } from "@glimmer/tracking";
import EmberObject, { set } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { and, equal, not, or, reads } from "@ember/object/computed";
import { next, throttle } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { observes, on } from "@ember-decorators/object";
import { Promise } from "rsvp";
import { extractError, throwAjaxError } from "discourse/lib/ajax-error";
import { QUOTE_REGEXP } from "discourse/lib/quote";
import { prioritizeNameFallback } from "discourse/lib/settings";
import { emailValid, escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import Draft from "discourse/models/draft";
import RestModel from "discourse/models/rest";
import Site from "discourse/models/site";
import Topic from "discourse/models/topic";
import User from "discourse/models/user";
import { tinyAvatar } from "discourse-common/lib/avatar-utils";
import deprecated from "discourse-common/lib/deprecated";
import discourseComputed from "discourse-common/utils/decorators";
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
  NEW_TOPIC_KEY = "new_topic";

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
    tags: "tags",
    featured_link: "featuredLink",
    shared_draft: "sharedDraft",
    no_bump: "noBump",
    draft_key: "draftKey",
  },
  _update_serializer = {
    raw: "reply",
    topic_id: "topic.id",
    original_text: "originalText",
  },
  _edit_topic_serializer = {
    title: "topic.title",
    categoryId: "topic.category.id",
    tags: "topic.tags",
    featuredLink: "topic.featured_link",
    original_title: "originalTitle",
    original_tags: "originalTags",
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

  // Draft key
  static NEW_PRIVATE_MESSAGE_KEY = NEW_PRIVATE_MESSAGE_KEY;
  static NEW_TOPIC_KEY = NEW_TOPIC_KEY;

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

  @tracked topic;
  @tracked post;
  @tracked reply;
  @tracked whisper;

  unlistTopic = false;
  noBump = false;
  draftSaving = false;
  draftForceSave = false;
  showFullScreenExitPrompt = false;
  @reads("site.archetypes") archetypes;
  @equal("action", CREATE_SHARED_DRAFT) sharedDraft;
  @equal("action", CREATE_TOPIC) creatingTopic;
  @equal("action", CREATE_SHARED_DRAFT) creatingSharedDraft;
  @equal("action", PRIVATE_MESSAGE) creatingPrivateMessage;
  @not("creatingPrivateMessage") notCreatingPrivateMessage;
  @not("privateMessage") notPrivateMessage;
  @or("creatingTopic", "editingFirstPost") topicFirstPost;
  @equal("composeState", OPEN) viewOpen;
  @equal("composeState", DRAFT) viewDraft;
  @equal("composeState", FULLSCREEN) viewFullscreen;
  @or("viewOpen", "viewFullscreen") viewOpenOrFullscreen;
  @and("editingPost", "post.firstPost") editingFirstPost;

  @or(
    "creatingTopic",
    "creatingPrivateMessage",
    "editingFirstPost",
    "creatingSharedDraft"
  )
  canEditTitle;

  @and("canEditTitle", "notCreatingPrivateMessage", "notPrivateMessage")
  canCategorize;

  @tracked _categoryId = null;

  @discourseComputed("reply", "originalText")
  replyDirty(reply, original) {
    return (reply || "").trim() !== (original || "").trim();
  }

  @discourseComputed("title", "originalTitle")
  titleDirty(title, original) {
    return (title || "").trim() !== (original || "").trim();
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

  @discourseComputed("categoryId")
  category(categoryId) {
    return categoryId ? Category.findById(categoryId) : null;
  }

  @dependentKeyCompat
  get replyingToTopic() {
    return this.get("action") === REPLY;
  }

  @dependentKeyCompat
  get editingPost() {
    return isEdit(this.get("action"));
  }

  @discourseComputed("category.minimumRequiredTags")
  minimumRequiredTags(minimumRequiredTags) {
    return minimumRequiredTags || 0;
  }

  @discourseComputed("editingPost", "topic.details.can_edit")
  disableTitleInput(editingPost, canEditTopic) {
    return editingPost && !canEditTopic;
  }

  @discourseComputed("privateMessage", "archetype.hasOptions")
  showCategoryChooser(isPrivateMessage, hasOptions) {
    const manyCategories = this.site.categories.length > 1;
    return !isPrivateMessage && (hasOptions || manyCategories);
  }

  @discourseComputed("creatingPrivateMessage", "topic")
  privateMessage(creatingPrivateMessage, topic) {
    return (
      creatingPrivateMessage || (topic && topic.archetype === "private_message")
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

  @discourseComputed("archetypeId")
  archetype(archetypeId) {
    return this.archetypes.findBy("id", archetypeId);
  }

  @observes("archetype")
  archetypeChanged() {
    return this.set("metaData", EmberObject.create());
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

  @discourseComputed(
    "canEditTitle",
    "creatingPrivateMessage",
    "categoryId",
    "user.trust_level"
  )
  canEditTopicFeaturedLink(
    canEditTitle,
    creatingPrivateMessage,
    categoryId,
    userTrustLevel
  ) {
    if (userTrustLevel === 0) {
      return false;
    }

    if (
      !this.siteSettings.topic_featured_link_enabled ||
      !canEditTitle ||
      creatingPrivateMessage
    ) {
      return false;
    }

    const categoryIds = this.site.topic_featured_link_allowed_category_ids;
    if (
      !categoryId &&
      categoryIds &&
      (categoryIds.includes(this.site.uncategorized_category_id) ||
        !this.siteSettings.allow_uncategorized_topics)
    ) {
      return true;
    }
    return (
      categoryIds === undefined ||
      !categoryIds.length ||
      categoryIds.includes(categoryId)
    );
  }

  @discourseComputed("canEditTopicFeaturedLink")
  titlePlaceholder(canEditTopicFeaturedLink) {
    return canEditTopicFeaturedLink
      ? "composer.title_or_link_placeholder"
      : "composer.title_placeholder";
  }

  @discourseComputed("action", "post", "topic", "topic.title")
  replyOptions(action, post, topic, topicTitle) {
    const options = {
      userLink: null,
      topicLink: null,
      postLink: null,
      userAvatar: null,
      originalUser: null,
    };

    if (topic) {
      options.topicLink = {
        href: topic.url,
        anchor: topic.fancyTitle || escapeExpression(topicTitle),
      };
    }

    if (post) {
      options.label = i18n(`post.${action}`);
      options.userAvatar = tinyAvatar(post.avatar_template);

      if (this.site.desktopView) {
        const originalUserName = post.get("reply_to_user.username");
        const originalUserAvatar = post.get("reply_to_user.avatar_template");
        if (originalUserName && originalUserAvatar && isEdit(action)) {
          options.originalUser = {
            username: originalUserName,
            avatar: tinyAvatar(originalUserAvatar),
          };
        }
      }
    }

    if (topic && post) {
      const postNumber = post.post_number;

      options.postLink = {
        href: `${topic.url}/${postNumber}`,
        anchor: i18n("post.post_number", { number: postNumber }),
      };

      const name = prioritizeNameFallback(post.name, post.username);

      options.userLink = {
        href: `${topic.url}/${postNumber}`,
        anchor: name,
      };
    }

    return options;
  }

  @discourseComputed("targetRecipients")
  targetRecipientsArray(targetRecipients) {
    const recipients = targetRecipients ? targetRecipients.split(",") : [];
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

  @discourseComputed(
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
  cantSubmitPost(
    loading,
    canEditTitle,
    titleLength,
    targetRecipients,
    targetRecipientsArray,
    replyLength,
    categoryId,
    missingReplyCharacters,
    tags,
    topicFirstPost,
    minimumRequiredTags,
    isStaffUser
  ) {
    // can't submit while loading
    if (loading) {
      return true;
    }

    // title is required when
    //  - creating a new topic/private message
    //  - editing the 1st post
    if (canEditTitle && !this.titleLengthValid) {
      return true;
    }

    // reply is always required
    if (missingReplyCharacters > 0) {
      return true;
    }

    if (
      this.site.can_tag_topics &&
      !isStaffUser &&
      topicFirstPost &&
      minimumRequiredTags
    ) {
      const tagsArray = tags || [];
      if (tagsArray.length < minimumRequiredTags) {
        return true;
      }
    }

    if (topicFirstPost) {
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
      return targetRecipients && targetRecipientsArray.length === 0;
    } else {
      // has a category? (when needed)
      return this.requiredCategoryMissing;
    }
  }

  @discourseComputed("canCategorize", "categoryId")
  requiredCategoryMissing(canCategorize, categoryId) {
    return (
      canCategorize &&
      !categoryId &&
      !this.siteSettings.allow_uncategorized_topics &&
      !!this._hasTopicTemplates
    );
  }

  @discourseComputed("minimumTitleLength", "titleLength", "post.static_doc")
  titleLengthValid(minTitleLength, titleLength, staticDoc) {
    if (this.user.admin && staticDoc && titleLength > 0) {
      return true;
    }
    if (titleLength < minTitleLength) {
      return false;
    }
    return titleLength <= this.siteSettings.max_topic_title_length;
  }

  @discourseComputed("metaData")
  hasMetaData(metaData) {
    return metaData ? isEmpty(Object.keys(metaData)) : false;
  }

  @discourseComputed("minimumTitleLength", "titleLength")
  missingTitleCharacters(minimumTitleLength, titleLength) {
    return minimumTitleLength - titleLength;
  }

  @discourseComputed("privateMessage")
  minimumTitleLength(privateMessage) {
    if (privateMessage) {
      return this.siteSettings.min_personal_message_title_length;
    } else {
      return this.siteSettings.min_topic_title_length;
    }
  }

  @discourseComputed(
    "minimumPostLength",
    "replyLength",
    "canEditTopicFeaturedLink"
  )
  missingReplyCharacters(
    minimumPostLength,
    replyLength,
    canEditTopicFeaturedLink
  ) {
    if (
      this.get("post.post_type") === this.site.get("post_types.small_action") ||
      (canEditTopicFeaturedLink && this.featuredLink)
    ) {
      return 0;
    }
    return minimumPostLength - replyLength;
  }

  @discourseComputed(
    "privateMessage",
    "topicFirstPost",
    "topic.pm_with_non_human_user"
  )
  minimumPostLength(privateMessage, topicFirstPost, pmWithNonHumanUser) {
    if (pmWithNonHumanUser) {
      return 1;
    } else if (privateMessage) {
      return this.siteSettings.min_personal_message_post_length;
    } else if (topicFirstPost) {
      // first post (topic body)
      return this.siteSettings.min_first_post_length;
    } else {
      return this.siteSettings.min_post_length;
    }
  }

  @discourseComputed("title")
  titleLength(title) {
    title = title || "";
    return title.replace(/\s+/gim, " ").trim().length;
  }

  @discourseComputed("reply")
  replyLength(reply) {
    reply = reply || "";

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
    this.set("archetypeId", this.site.default_archetype);
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

    this.set("reply", before + text + after);

    return before.length + text.length;
  }

  prependText(text, opts) {
    const reply = this.reply || "";

    if (opts && opts.new_line && reply.length > 0) {
      text = text.trim() + "\n\n";
    }

    this.set("reply", text + reply);
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
      this.set("reply", category.topic_template || "");
      this.set("originalText", category.topic_template || "");
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

    this.set("loading", true);

    if (
      !isEmpty(this.reply) &&
      (opts.reply || isEdit(opts.action)) &&
      this.replyDirty
    ) {
      return promise;
    }

    if (opts.action === REPLY && isEdit(this.action)) {
      this.set("reply", "");
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
        this.set("topic", opts.post.topic);
      }
    } else if (opts.postId) {
      promise = promise.then(() =>
        this.store.find("post", opts.postId).then((post) => {
          this.set("post", post);
          if (post) {
            this.set("topic", post.topic);
          }
        })
      );
    } else {
      this.set("post", null);
    }

    this.setProperties({
      archetypeId: opts.archetypeId || this.site.default_archetype,
      metaData: opts.metaData ? EmberObject.create(opts.metaData) : null,
      reply: opts.reply || this.reply || "",
    });

    // We set the category id separately for topic templates on opening of composer
    this.set(
      "categoryId",
      opts.topicCategoryId || opts.categoryId || this.get("topic.category.id")
    );

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

      promise = promise.then(() => {
        let rawPromise = this.store.find("post", opts.post.id).then((post) => {
          this.setProperties({
            post,
            reply: post.raw,
            originalText: post.raw,
          });

          if (post.topic && post.post_number === 1 && this.canEditTitle) {
            this.setProperties({
              originalTitle: post.topic.title,
              originalTags: post.topic.tags,
            });
          }
        });

        // edge case ... make a post then edit right away
        // store does not have topic for the post
        if (this.topic && this.topic.id === this.post.topic_id) {
          // nothing to do ... we have the right topic
        } else {
          rawPromise = this.store
            .find("topic", this.post.topic_id)
            .then((topic) => {
              this.set("topic", topic);
            });
        }

        return rawPromise.then(() => {
          this.appEvents.trigger("composer:reply-reloaded", this);
        });
      });
    } else if (opts.action === REPLY && opts.quote) {
      this.set("reply", opts.quote);
      this.set("originalText", opts.quote);
    }

    if (opts.title) {
      this.set("title", opts.title);
    }

    if (this.canEditTitle) {
      if (isEmpty(this.title) && this.title !== "") {
        this.set("title", "");
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
      this.set("loading", false);
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
          this.set("featuredLink", null);
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
    this.set("composeState", SAVING);

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
      this.set("composeState", OPEN);
      if (error.jqXHR && error.jqXHR.status === 409) {
        this.set("editConflict", true);
      }
    });

    const cooked = this.getCookedHtml();
    post.setProperties({ cooked, staged: true });
    this.appEvents.trigger("post-stream:refresh", { id: post.id });

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
        this.appEvents.trigger("post-stream:refresh", { id: post.id });
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
      this.set("topic", null);
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
        this.set("composeState", CLOSED);
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
        this.set("composeState", CLOSED);
      } else if (saving) {
        this.set("composeState", SAVING);
      }

      return result;
    } catch (error) {
      if (postStream) {
        postStream.undoPost(createdPost);

        post?.set("reply_count", post.reply_count - 1);
      }

      next(() => this.set("composeState", OPEN));

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

  @discourseComputed(
    "draftSaving",
    "disableDrafts",
    "canEditTitle",
    "title",
    "reply",
    "titleLengthValid",
    "replyLength",
    "minimumPostLength"
  )
  canSaveDraft() {
    if (this.draftSaving) {
      return false;
    }

    // Do not save when drafts are disabled
    if (this.disableDrafts) {
      return false;
    }

    if (this.canEditTitle) {
      // Save title and/or post body
      if (isEmpty(this.title) && isEmpty(this.reply)) {
        return false;
      }

      // Do not save when both title and reply's length are too small
      if (!this.titleLengthValid && this.replyLength < this.minimumPostLength) {
        return false;
      }
    } else {
      // Do not save when there is no reply
      if (isEmpty(this.reply)) {
        return false;
      }
    }

    return true;
  }

  saveDraft(user) {
    if (!this.canSaveDraft) {
      return Promise.resolve();
    }

    this.set("draftSaving", true);

    const data = this.serialize(_draft_serializer);

    const draftSequence = this.draftSequence;
    this.set("draftSequence", this.draftSequence + 1);

    return Draft.save(
      this.draftKey,
      draftSequence,
      data,
      this.messageBus.clientId,
      { forceSave: this.draftForceSave }
    )
      .then((result) => {
        if ("draft_sequence" in result) {
          this.set("draftSequence", result.draft_sequence);
        }
        if (result.conflict_user) {
          this.setProperties({
            draftStatus: i18n("composer.edit_conflict"),
            draftConflictUser: result.conflict_user,
          });
        } else {
          if (this.draftKey === NEW_TOPIC_KEY && user) {
            user.set("has_topic_draft", true);
          }

          this.setProperties({
            draftStatus: null,
            draftConflictUser: null,
            draftForceSave: false,
          });
        }
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
                  class: "btn",
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
        this.set("draftSaving", false);
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
