import EmberObject from "@ember/object";
import { next } from "@ember/runloop";
import { cancel } from "@ember/runloop";
import { later } from "@ember/runloop";
import RestModel from "discourse/models/rest";
import Topic from "discourse/models/topic";
import { throwAjaxError } from "discourse/lib/ajax-error";
import Quote from "discourse/lib/quote";
import Draft from "discourse/models/draft";
import {
  default as computed,
  observes,
  on
} from "ember-addons/ember-computed-decorators";
import { escapeExpression, tinyAvatar } from "discourse/lib/utilities";
import { propertyNotEqual } from "discourse/lib/computed";
import throttle from "discourse/lib/throttle";

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
    target_usernames: "targetUsernames",
    typing_duration_msecs: "typingTime",
    composer_open_duration_msecs: "composerTime",
    tags: "tags",
    featured_link: "featuredLink",
    shared_draft: "sharedDraft",
    no_bump: "noBump"
  },
  _edit_topic_serializer = {
    title: "topic.title",
    categoryId: "topic.category.id",
    tags: "topic.tags",
    featuredLink: "topic.featured_link"
  },
  _draft_serializer = {
    reply: "reply",
    action: "action",
    title: "title",
    categoryId: "categoryId",
    archetypeId: "archetypeId",
    whisper: "whisper",
    metaData: "metaData",
    composerTime: "composerTime",
    typingTime: "typingTime",
    postId: "post.id",
    usernames: "targetUsernames"
  },
  _add_draft_fields = {},
  FAST_REPLY_LENGTH_THRESHOLD = 10000;

export const SAVE_LABELS = {
  [EDIT]: "composer.save_edit",
  [REPLY]: "composer.reply",
  [CREATE_TOPIC]: "composer.create_topic",
  [PRIVATE_MESSAGE]: "composer.create_pm",
  [CREATE_SHARED_DRAFT]: "composer.create_shared_draft",
  [EDIT_SHARED_DRAFT]: "composer.save_edit"
};

export const SAVE_ICONS = {
  [EDIT]: "pencil-alt",
  [EDIT_SHARED_DRAFT]: "far-clipboard",
  [REPLY]: "reply",
  [CREATE_TOPIC]: "plus",
  [PRIVATE_MESSAGE]: "envelope",
  [CREATE_SHARED_DRAFT]: "far-clipboard"
};

const Composer = RestModel.extend({
  _categoryId: null,
  unlistTopic: false,
  noBump: false,
  draftSaving: false,
  draftSaved: false,

  archetypes: Ember.computed.reads("site.archetypes"),

  sharedDraft: Ember.computed.equal("action", CREATE_SHARED_DRAFT),

  @computed
  categoryId: {
    get() {
      return this._categoryId;
    },

    // We wrap categoryId this way so we can fire `applyTopicTemplate` with
    // the previous value as well as the new value
    set(categoryId) {
      const oldCategoryId = this._categoryId;

      if (Ember.isEmpty(categoryId)) {
        categoryId = null;
      }
      this._categoryId = categoryId;

      if (oldCategoryId !== categoryId) {
        this.applyTopicTemplate(oldCategoryId, categoryId);
      }

      return categoryId;
    }
  },

  @computed("categoryId")
  category(categoryId) {
    return categoryId ? this.site.categories.findBy("id", categoryId) : null;
  },

  @computed("category")
  minimumRequiredTags(category) {
    return category && category.minimum_required_tags > 0
      ? category.minimum_required_tags
      : null;
  },

  creatingTopic: Ember.computed.equal("action", CREATE_TOPIC),
  creatingSharedDraft: Ember.computed.equal("action", CREATE_SHARED_DRAFT),
  creatingPrivateMessage: Ember.computed.equal("action", PRIVATE_MESSAGE),
  notCreatingPrivateMessage: Ember.computed.not("creatingPrivateMessage"),
  notPrivateMessage: Ember.computed.not("privateMessage"),

  @computed("editingPost", "topic.details.can_edit")
  disableTitleInput(editingPost, canEditTopic) {
    return editingPost && !canEditTopic;
  },

  @computed("privateMessage", "archetype.hasOptions")
  showCategoryChooser(isPrivateMessage, hasOptions) {
    const manyCategories = this.site.categories.length > 1;
    return !isPrivateMessage && (hasOptions || manyCategories);
  },

  @computed("creatingPrivateMessage", "topic")
  privateMessage(creatingPrivateMessage, topic) {
    return (
      creatingPrivateMessage || (topic && topic.archetype === "private_message")
    );
  },

  topicFirstPost: Ember.computed.or("creatingTopic", "editingFirstPost"),

  @computed("action")
  editingPost: isEdit,

  replyingToTopic: Ember.computed.equal("action", REPLY),

  viewOpen: Ember.computed.equal("composeState", OPEN),
  viewDraft: Ember.computed.equal("composeState", DRAFT),
  viewFullscreen: Ember.computed.equal("composeState", FULLSCREEN),
  viewOpenOrFullscreen: Ember.computed.or("viewOpen", "viewFullscreen"),

  @observes("composeState")
  composeStateChanged() {
    const oldOpen = this.composerOpened;
    const elem = document.querySelector("html");

    if (this.composeState === FULLSCREEN) {
      elem.classList.add("fullscreen-composer");
    } else {
      elem.classList.remove("fullscreen-composer");
    }

    if (this.composeState === OPEN) {
      this.set("composerOpened", oldOpen || new Date());
    } else {
      if (oldOpen) {
        const oldTotal = this.composerTotalOpened || 0;
        this.set("composerTotalOpened", oldTotal + (new Date() - oldOpen));
      }
      this.set("composerOpened", null);
    }
  },

  @computed
  composerTime: {
    get() {
      let total = this.composerTotalOpened || 0;
      const oldOpen = this.composerOpened;

      if (oldOpen) {
        total += new Date() - oldOpen;
      }

      return total;
    }
  },

  @computed("archetypeId")
  archetype(archetypeId) {
    return this.archetypes.findBy("id", archetypeId);
  },

  @observes("archetype")
  archetypeChanged() {
    return this.set("metaData", EmberObject.create());
  },

  // view detected user is typing
  typing: throttle(
    function() {
      const typingTime = this.typingTime || 0;
      this.set("typingTime", typingTime + 100);
    },
    100,
    false
  ),

  editingFirstPost: Ember.computed.and("editingPost", "post.firstPost"),

  canEditTitle: Ember.computed.or(
    "creatingTopic",
    "creatingPrivateMessage",
    "editingFirstPost",
    "creatingSharedDraft"
  ),

  canCategorize: Ember.computed.and(
    "canEditTitle",
    "notCreatingPrivateMessage",
    "notPrivateMessage"
  ),

  @computed("canEditTitle", "creatingPrivateMessage", "categoryId")
  canEditTopicFeaturedLink(canEditTitle, creatingPrivateMessage, categoryId) {
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
      (categoryIds.indexOf(this.site.uncategorized_category_id) !== -1 ||
        !this.siteSettings.allow_uncategorized_topics)
    ) {
      return true;
    }
    return (
      categoryIds === undefined ||
      !categoryIds.length ||
      categoryIds.indexOf(categoryId) !== -1
    );
  },

  @computed("canEditTopicFeaturedLink")
  titlePlaceholder(canEditTopicFeaturedLink) {
    return canEditTopicFeaturedLink
      ? "composer.title_or_link_placeholder"
      : "composer.title_placeholder";
  },

  @computed("action", "post", "topic", "topic.title")
  replyOptions(action, post, topic, topicTitle) {
    const options = {
      userLink: null,
      topicLink: null,
      postLink: null,
      userAvatar: null,
      originalUser: null
    };

    if (topic) {
      options.topicLink = {
        href: topic.url,
        anchor: topic.fancy_title || escapeExpression(topicTitle)
      };
    }

    if (post) {
      options.label = I18n.t(`post.${action}`);
      options.userAvatar = tinyAvatar(post.avatar_template);

      if (!this.site.mobileView) {
        const originalUserName = post.get("reply_to_user.username");
        const originalUserAvatar = post.get("reply_to_user.avatar_template");
        if (originalUserName && originalUserAvatar && isEdit(action)) {
          options.originalUser = {
            username: originalUserName,
            avatar: tinyAvatar(originalUserAvatar)
          };
        }
      }
    }

    if (topic && post) {
      const postNumber = post.post_number;

      options.postLink = {
        href: `${topic.url}/${postNumber}`,
        anchor: I18n.t("post.post_number", { number: postNumber })
      };

      options.userLink = {
        href: `${topic.url}/${postNumber}`,
        anchor: post.username
      };
    }

    return options;
  },

  @computed(
    "loading",
    "canEditTitle",
    "titleLength",
    "targetUsernames",
    "replyLength",
    "categoryId",
    "missingReplyCharacters",
    "tags",
    "topicFirstPost",
    "minimumRequiredTags",
    "isStaffUser"
  )
  cantSubmitPost(
    loading,
    canEditTitle,
    titleLength,
    targetUsernames,
    replyLength,
    categoryId,
    missingReplyCharacters,
    tags,
    topicFirstPost,
    minimumRequiredTags,
    isStaffUser
  ) {
    // can't submit while loading
    if (loading) return true;

    // title is required when
    //  - creating a new topic/private message
    //  - editing the 1st post
    if (canEditTitle && !this.titleLengthValid) return true;

    // reply is always required
    if (missingReplyCharacters > 0) return true;

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
          bootbox.alert(I18n.t("composer.error.topic_template_not_modified"));
          return true;
        }
      }
    }

    if (this.privateMessage) {
      // need at least one user when sending a PM
      return (
        targetUsernames && (targetUsernames.trim() + ",").indexOf(",") === 0
      );
    } else {
      // has a category? (when needed)
      return this.requiredCategoryMissing;
    }
  },

  @computed("canCategorize", "categoryId")
  requiredCategoryMissing(canCategorize, categoryId) {
    return (
      canCategorize &&
      !categoryId &&
      !this.siteSettings.allow_uncategorized_topics
    );
  },

  @computed("minimumTitleLength", "titleLength", "post.static_doc")
  titleLengthValid(minTitleLength, titleLength, staticDoc) {
    if (this.user.admin && staticDoc && titleLength > 0) return true;
    if (titleLength < minTitleLength) return false;
    return titleLength <= this.siteSettings.max_topic_title_length;
  },

  @computed("metaData")
  hasMetaData(metaData) {
    return metaData ? Ember.isEmpty(Ember.keys(metaData)) : false;
  },

  replyDirty: propertyNotEqual("reply", "originalText"),

  titleDirty: propertyNotEqual("title", "originalTitle"),

  @computed("minimumTitleLength", "titleLength")
  missingTitleCharacters(minimumTitleLength, titleLength) {
    return minimumTitleLength - titleLength;
  },

  @computed("privateMessage")
  minimumTitleLength(privateMessage) {
    if (privateMessage) {
      return this.siteSettings.min_personal_message_title_length;
    } else {
      return this.siteSettings.min_topic_title_length;
    }
  },

  @computed("minimumPostLength", "replyLength", "canEditTopicFeaturedLink")
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
  },

  @computed("privateMessage", "topicFirstPost", "topic.pm_with_non_human_user")
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
  },

  @computed("title")
  titleLength(title) {
    title = title || "";
    return title.replace(/\s+/gim, " ").trim().length;
  },

  @computed("reply")
  replyLength(reply) {
    reply = reply || "";

    if (reply.length > FAST_REPLY_LENGTH_THRESHOLD) {
      return reply.length;
    }

    while (Quote.REGEXP.test(reply)) {
      // make it global so we can strip as many quotes at once
      // keep in mind nested quotes mean we still need a loop here
      const regex = new RegExp(Quote.REGEXP.source, "img");
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
  },

  @on("init")
  _setupComposer() {
    this.set("archetypeId", this.site.default_archetype);
  },

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

    this.set("reply", before + text + after);

    return before.length + text.length;
  },

  prependText(text, opts) {
    const reply = this.reply || "";

    if (opts && opts.new_line && reply.length > 0) {
      text = text.trim() + "\n\n";
    }

    this.set("reply", text + reply);
  },

  applyTopicTemplate(oldCategoryId, categoryId) {
    if (this.action !== CREATE_TOPIC) {
      return;
    }

    let reply = this.reply;

    // If the user didn't change the template, clear it
    if (oldCategoryId) {
      const oldCat = this.site.categories.findBy("id", oldCategoryId);
      if (oldCat && oldCat.topic_template === reply) {
        reply = "";
      }
    }

    if (!Ember.isEmpty(reply)) {
      return;
    }

    const category = this.site.categories.findBy("id", categoryId);
    if (category) {
      this.set("reply", category.topic_template || "");
    }
  },

  /*
     Open a composer

     opts:
       action   - The action we're performing: edit, reply or createTopic
       post     - The post we're replying to, if present
       topic    - The topic we're replying to, if present
       quote    - If we're opening a reply from a quote, the quote we're making
  */
  open(opts) {
    if (!opts) opts = {};
    this.set("loading", false);

    const replyBlank = Ember.isEmpty(this.reply);

    const composer = this;
    if (
      !replyBlank &&
      ((opts.reply || isEdit(opts.action)) && this.replyDirty)
    ) {
      return;
    }

    if (opts.action === REPLY && isEdit(this.action)) {
      this.set("reply", "");
    }

    if (!opts.draftKey) throw new Error("draft key is required");

    if (opts.draftSequence === null) {
      throw new Error("draft sequence is required");
    }

    this.setProperties({
      draftKey: opts.draftKey,
      draftSequence: opts.draftSequence,
      composeState: opts.composerState || OPEN,
      action: opts.action,
      topic: opts.topic,
      targetUsernames: opts.usernames,
      composerTotalOpened: opts.composerTime,
      typingTime: opts.typingTime,
      whisper: opts.whisper,
      tags: opts.tags,
      noBump: opts.noBump
    });

    if (opts.post) {
      this.setProperties({
        post: opts.post,
        whisper: opts.post.post_type === this.site.post_types.whisper
      });

      if (!this.topic) {
        this.set("topic", opts.post.topic);
      }
    } else {
      this.set("post", null);
    }

    this.setProperties({
      archetypeId: opts.archetypeId || this.site.default_archetype,
      metaData: opts.metaData ? EmberObject.create(opts.metaData) : null,
      reply: opts.reply || this.reply || ""
    });

    // We set the category id separately for topic templates on opening of composer
    this.set("categoryId", opts.categoryId || this.get("topic.category.id"));

    if (!this.categoryId && this.creatingTopic) {
      const categories = this.site.categories;
      if (categories.length === 1) {
        this.set("categoryId", categories[0].id);
      }
    }

    if (opts.postId) {
      this.set("loading", true);

      this.store
        .find("post", opts.postId)
        .then(post => composer.setProperties({ post, loading: false }));
    }

    // If we are editing a post, load it.
    if (isEdit(opts.action) && opts.post) {
      const topicProps = this.serialize(_edit_topic_serializer);
      topicProps.loading = true;

      // When editing a shared draft, use its category
      if (opts.action === EDIT_SHARED_DRAFT && opts.destinationCategoryId) {
        topicProps.categoryId = opts.destinationCategoryId;
      }
      this.setProperties(topicProps);

      this.store.find("post", opts.post.id).then(post => {
        composer.setProperties({
          reply: post.raw,
          originalText: post.raw,
          loading: false
        });

        composer.appEvents.trigger("composer:reply-reloaded", composer);
      });
    } else if (opts.action === REPLY && opts.quote) {
      this.setProperties({
        reply: opts.quote,
        originalText: opts.quote
      });
    }

    if (opts.title) {
      this.set("title", opts.title);
    }

    this.set("originalText", opts.draft ? "" : this.reply);
    if (this.editingFirstPost) {
      this.set("originalTitle", this.title);
    }

    if (!isEdit(opts.action) || !opts.post) {
      composer.appEvents.trigger("composer:reply-reloaded", composer);
    }

    // Ensure additional draft fields are set
    Object.keys(_add_draft_fields).forEach(f => {
      this.set(_add_draft_fields[f], opts[f]);
    });

    return false;
  },

  // Overwrite to implement custom logic
  beforeSave() {
    return Ember.RSVP.Promise.resolve();
  },

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
  },

  clearState() {
    this.setProperties({
      originalText: null,
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
      editConflict: false
    });
  },

  editPost(opts) {
    const post = this.post;
    const oldCooked = post.cooked;
    let promise = Ember.RSVP.resolve();

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

    const props = {
      topic_id: this.topic.id,
      raw: this.reply,
      raw_old: this.editConflict ? null : this.originalText,
      edit_reason: opts.editReason,
      image_sizes: opts.imageSizes,
      cooked: this.getCookedHtml()
    };

    this.set("composeState", SAVING);

    const rollback = throwAjaxError(error => {
      post.set("cooked", oldCooked);
      this.set("composeState", OPEN);
      if (error.jqXHR && error.jqXHR.status === 409) {
        this.set("editConflict", true);
      }
    });

    return promise
      .then(() => {
        // rest model only sets props after it is saved
        post.set("cooked", props.cooked);
        return post.save(props).then(result => {
          this.clearState();
          return result;
        });
      })
      .catch(rollback);
  },

  serialize(serializer, dest) {
    dest = dest || {};
    Object.keys(serializer).forEach(f => {
      const val = this.get(serializer[f]);
      if (typeof val !== "undefined") {
        Ember.set(dest, f, val);
      }
    });
    return dest;
  },

  createPost(opts) {
    const post = this.post;
    const topic = this.topic;
    const user = this.user;
    const postStream = this.get("topic.postStream");
    let addedToStream = false;
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
      composerTime: this.composerTime
    });

    this.serialize(_create_serializer, createdPost);

    if (post) {
      createdPost.setProperties({
        reply_to_post_number: post.post_number,
        reply_to_user: post.getProperties("username", "avatar_template")
      });
    }

    let state = null;

    // If we're in a topic, we can append the post instantly.
    if (postStream) {
      // If it's in reply to another post, increase the reply count
      if (post) {
        post.setProperties({
          reply_count: (post.reply_count || 0) + 1,
          replies: []
        });
      }

      // We do not stage posts in mobile view, we do not have the "cooked"
      // Furthermore calculating cooked is very complicated, especially since
      // we would need to handle oneboxes and other bits that are not even in the
      // engine, staging will just cause a blank post to render
      if (!_.isEmpty(createdPost.cooked)) {
        state = postStream.stagePost(createdPost, user);
        if (state === "alreadyStaging") {
          return;
        }
      }
    }

    const composer = this;
    composer.setProperties({
      composeState: SAVING,
      stagedPost: state === "staged" && createdPost
    });

    return createdPost
      .save()
      .then(result => {
        let saving = true;

        if (result.responseJson.action === "enqueued") {
          if (postStream) {
            postStream.undoPost(createdPost);
          }
          return result;
        }

        // We sometimes want to hide the `reply_to_user` if the post contains a quote
        if (
          result.responseJson &&
          result.responseJson.post &&
          !result.responseJson.post.reply_to_user
        ) {
          createdPost.set("reply_to_user", null);
        }

        if (topic) {
          // It's no longer a new post
          topic.set("draft_sequence", result.target.draft_sequence);
          postStream.commitPost(createdPost);
          addedToStream = true;
        } else {
          // We created a new topic, let's show it.
          composer.set("composeState", CLOSED);
          saving = false;

          // Update topic_count for the category
          const category = composer.site.categories.find(
            x => x.id === (parseInt(createdPost.category, 10) || 1)
          );
          if (category) category.incrementProperty("topic_count");
          Discourse.notifyPropertyChange("globalNotice");
        }

        composer.clearState();
        composer.set("createdPost", createdPost);
        if (composer.replyingToTopic) {
          this.appEvents.trigger("post:created", createdPost);
        } else {
          this.appEvents.trigger("topic:created", createdPost, composer);
        }

        if (addedToStream) {
          composer.set("composeState", CLOSED);
        } else if (saving) {
          composer.set("composeState", SAVING);
        }

        return result;
      })
      .catch(
        throwAjaxError(() => {
          if (postStream) {
            postStream.undoPost(createdPost);

            if (post) {
              post.set("reply_count", post.reply_count - 1);
            }
          }
          next(() => composer.set("composeState", OPEN));
        })
      );
  },

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
  },

  saveDraft() {
    // Do not save when drafts are disabled
    if (this.disableDrafts) return;

    if (this.canEditTitle) {
      // Save title and/or post body
      if (!this.title && !this.reply) return;

      if (
        this.title &&
        this.titleLengthValid &&
        this.reply &&
        this.replyLength < this.siteSettings.min_post_length
      ) {
        return;
      }
    } else {
      // Do not save when there is no reply
      if (!this.reply) return;

      // Do not save when the reply's length is too small
      if (this.replyLength < this.siteSettings.min_post_length) return;
    }

    this.setProperties({
      draftSaved: false,
      draftSaving: true,
      draftConflictUser: null
    });

    if (this._clearingStatus) {
      cancel(this._clearingStatus);
      this._clearingStatus = null;
    }

    let data = this.serialize(_draft_serializer);

    if (data.postId && !Ember.isEmpty(this.originalText)) {
      data.originalText = this.originalText;
    }

    return Draft.save(this.draftKey, this.draftSequence, data)
      .then(result => {
        if (result.conflict_user) {
          this.setProperties({
            draftSaving: false,
            draftStatus: I18n.t("composer.edit_conflict"),
            draftConflictUser: result.conflict_user
          });
        } else {
          this.setProperties({
            draftSaving: false,
            draftSaved: true,
            draftConflictUser: null
          });
        }
      })
      .catch(() => {
        this.setProperties({
          draftSaving: false,
          draftStatus: I18n.t("composer.drafts_offline"),
          draftConflictUser: null
        });
      });
  },

  @observes("title", "reply")
  dataChanged() {
    const draftStatus = this.draftStatus;

    if (draftStatus && !this._clearingStatus) {
      this._clearingStatus = later(
        this,
        () => {
          this.setProperties({ draftStatus: null, draftConflictUser: null });
          this._clearingStatus = null;
          this.setProperties({ draftSaving: false, draftSaved: false });
        },
        Ember.Test ? 0 : 1000
      );
    }
  }
});

Composer.reopenClass({
  // TODO: Replace with injection
  create(args) {
    args = args || {};
    args.user = args.user || Discourse.User.current();
    args.site = args.site || Discourse.Site.current();
    args.siteSettings = args.siteSettings || Discourse.SiteSettings;
    return this._super(args);
  },

  serializeToTopic(fieldName, property) {
    if (!property) {
      property = fieldName;
    }
    _edit_topic_serializer[fieldName] = property;
  },

  serializeOnCreate(fieldName, property) {
    if (!property) {
      property = fieldName;
    }
    _create_serializer[fieldName] = property;
  },

  serializedFieldsForCreate() {
    return Object.keys(_create_serializer);
  },

  serializeToDraft(fieldName, property) {
    if (!property) {
      property = fieldName;
    }
    _draft_serializer[fieldName] = property;
    _add_draft_fields[fieldName] = property;
  },

  serializedFieldsForDraft() {
    return Object.keys(_draft_serializer);
  },

  // The status the compose view can have
  CLOSED,
  SAVING,
  OPEN,
  DRAFT,
  FULLSCREEN,

  // The actions the composer can take
  CREATE_TOPIC,
  CREATE_SHARED_DRAFT,
  EDIT_SHARED_DRAFT,
  PRIVATE_MESSAGE,
  REPLY,
  EDIT,

  // Draft key
  NEW_PRIVATE_MESSAGE_KEY,
  NEW_TOPIC_KEY
});

export default Composer;
