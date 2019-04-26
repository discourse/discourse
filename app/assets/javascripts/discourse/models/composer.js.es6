import RestModel from "discourse/models/rest";
import Topic from "discourse/models/topic";
import { throwAjaxError } from "discourse/lib/ajax-error";
import Quote from "discourse/lib/quote";
import Draft from "discourse/models/draft";
import computed from "ember-addons/ember-computed-decorators";
import { escapeExpression, tinyAvatar } from "discourse/lib/utilities";

// The actions the composer can take
export const CREATE_TOPIC = "createTopic",
  CREATE_SHARED_DRAFT = "createSharedDraft",
  EDIT_SHARED_DRAFT = "editSharedDraft",
  PRIVATE_MESSAGE = "privateMessage",
  NEW_PRIVATE_MESSAGE_KEY = "new_private_message",
  NEW_TOPIC_KEY = "new_topic",
  REPLY = "reply",
  EDIT = "edit",
  REPLY_AS_NEW_TOPIC_KEY = "reply_as_new_topic",
  REPLY_AS_NEW_PRIVATE_MESSAGE_KEY = "reply_as_new_private_message";

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
  };

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
  [EDIT_SHARED_DRAFT]: "clipboard",
  [REPLY]: "reply",
  [CREATE_TOPIC]: "plus",
  [PRIVATE_MESSAGE]: "envelope",
  [CREATE_SHARED_DRAFT]: "clipboard"
};

const Composer = RestModel.extend({
  _categoryId: null,
  unlistTopic: false,
  noBump: false,
  draftSaving: false,
  draftSaved: false,

  @computed
  archetypes() {
    return this.site.get("archetypes");
  },

  @computed("action")
  sharedDraft: action => action === CREATE_SHARED_DRAFT,

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
    return category && category.get("minimum_required_tags") > 0
      ? category.get("minimum_required_tags")
      : null;
  },

  creatingTopic: Ember.computed.equal("action", CREATE_TOPIC),
  creatingSharedDraft: Ember.computed.equal("action", CREATE_SHARED_DRAFT),
  creatingPrivateMessage: Ember.computed.equal("action", PRIVATE_MESSAGE),
  notCreatingPrivateMessage: Ember.computed.not("creatingPrivateMessage"),
  notPrivateMessage: Ember.computed.not("privateMessage"),

  @computed("privateMessage", "archetype.hasOptions")
  showCategoryChooser(isPrivateMessage, hasOptions) {
    const manyCategories = this.site.get("categories").length > 1;
    return !isPrivateMessage && (hasOptions || manyCategories);
  },

  @computed("creatingPrivateMessage", "topic")
  privateMessage(creatingPrivateMessage, topic) {
    return (
      creatingPrivateMessage ||
      (topic && topic.get("archetype") === "private_message")
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

  composeStateChanged: function() {
    let oldOpen = this.get("composerOpened"),
      elem = $("html");

    if (this.get("composeState") === FULLSCREEN) {
      elem.addClass("fullscreen-composer");
    } else {
      elem.removeClass("fullscreen-composer");
    }

    if (this.get("composeState") === OPEN) {
      this.set("composerOpened", oldOpen || new Date());
    } else {
      if (oldOpen) {
        let oldTotal = this.get("composerTotalOpened") || 0;
        this.set("composerTotalOpened", oldTotal + (new Date() - oldOpen));
      }
      this.set("composerOpened", null);
    }
  }.observes("composeState"),

  composerTime: function() {
    let total = this.get("composerTotalOpened") || 0,
      oldOpen = this.get("composerOpened");
    if (oldOpen) {
      total += new Date() - oldOpen;
    }

    return total;
  }
    .property()
    .volatile(),

  @computed("archetypeId")
  archetype(archetypeId) {
    return this.get("archetypes").findBy("id", archetypeId);
  },

  archetypeChanged: function() {
    return this.set("metaData", Ember.Object.create());
  }.observes("archetype"),

  // view detected user is typing
  typing: _.throttle(
    function() {
      let typingTime = this.get("typingTime") || 0;
      this.set("typingTime", typingTime + 100);
    },
    100,
    { leading: false, trailing: true }
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

    const categoryIds = this.site.get(
      "topic_featured_link_allowed_category_ids"
    );
    if (
      !categoryId &&
      categoryIds &&
      (categoryIds.indexOf(this.site.get("uncategorized_category_id")) !== -1 ||
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
  titlePlaceholder() {
    return this.get("canEditTopicFeaturedLink")
      ? "composer.title_or_link_placeholder"
      : "composer.title_placeholder";
  },

  @computed("action", "post", "topic", "topic.title")
  replyOptions(action, post, topic, topicTitle) {
    let options = {
      userLink: null,
      topicLink: null,
      postLink: null,
      userAvatar: null,
      originalUser: null
    };

    if (topic) {
      options.topicLink = {
        href: topic.get("url"),
        anchor: topic.get("fancy_title") || escapeExpression(topicTitle)
      };
    }

    if (post) {
      options.label = I18n.t(`post.${action}`);
      options.userAvatar = tinyAvatar(post.get("avatar_template"));

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
      const postNumber = post.get("post_number");

      options.postLink = {
        href: `${topic.get("url")}/${postNumber}`,
        anchor: I18n.t("post.post_number", { number: postNumber })
      };

      options.userLink = {
        href: `${topic.get("url")}/${postNumber}`,
        anchor: post.get("username")
      };
    }

    return options;
  },

  @computed
  isStaffUser() {
    const currentUser = Discourse.User.current();
    return currentUser && currentUser.get("staff");
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
    if (canEditTitle && !this.get("titleLengthValid")) return true;

    // reply is always required
    if (missingReplyCharacters > 0) return true;

    if (
      this.site.get("can_tag_topics") &&
      !isStaffUser &&
      topicFirstPost &&
      minimumRequiredTags
    ) {
      const tagsArray = tags || [];
      if (tagsArray.length < minimumRequiredTags) {
        return true;
      }
    }

    if (this.get("privateMessage")) {
      // need at least one user when sending a PM
      return (
        targetUsernames && (targetUsernames.trim() + ",").indexOf(",") === 0
      );
    } else {
      // has a category? (when needed)
      return this.get("requiredCategoryMissing");
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
    if (this.user.get("admin") && staticDoc && titleLength > 0) return true;
    if (titleLength < minTitleLength) return false;
    return titleLength <= this.siteSettings.max_topic_title_length;
  },

  @computed("metaData")
  hasMetaData(metaData) {
    return metaData ? Ember.isEmpty(Ember.keys(this.get("metaData"))) : false;
  },

  /**
    Did the user make changes to the reply?

    @property replyDirty
  **/
  @computed("reply", "originalText")
  replyDirty(reply, originalText) {
    return reply !== originalText;
  },

  /**
    Did the user make changes to the topic title?

    @property titleDirty
  **/
  @computed("title", "originalTitle")
  titleDirty(title, originalTitle) {
    return title !== originalTitle;
  },

  /**
    Number of missing characters in the title until valid.

    @property missingTitleCharacters
  **/
  @computed("minimumTitleLength", "titleLength")
  missingTitleCharacters(minimumTitleLength, titleLength) {
    return minimumTitleLength - titleLength;
  },

  /**
    Minimum number of characters for a title to be valid.

    @property minimumTitleLength
  **/
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
      (canEditTopicFeaturedLink && this.get("featuredLink"))
    ) {
      return 0;
    }
    return minimumPostLength - replyLength;
  },

  /**
    Minimum number of characters for a post body to be valid.

    @property minimumPostLength
  **/
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

  /**
    Computes the length of the title minus non-significant whitespaces

    @property titleLength
  **/
  @computed("title")
  titleLength(title) {
    title = title || "";
    return title.replace(/\s+/gim, " ").trim().length;
  },

  /**
    Computes the length of the reply minus the quote(s) and non-significant whitespaces

    @property replyLength
  **/
  @computed("reply")
  replyLength(reply) {
    reply = reply || "";
    while (Quote.REGEXP.test(reply)) {
      reply = reply.replace(Quote.REGEXP, "");
    }
    return reply.replace(/\s+/gim, " ").trim().length;
  },

  _setupComposer: function() {
    this.set("archetypeId", this.site.get("default_archetype"));
  }.on("init"),

  /**
    Append text to the current reply

    @method appendText
    @param {String} text the text to append
  **/
  appendText(text, position, opts) {
    const reply = this.get("reply") || "";
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
    const reply = this.get("reply") || "";

    if (opts && opts.new_line && reply.length > 0) {
      text = text.trim() + "\n\n";
    }
    this.set("reply", text + reply);
  },

  applyTopicTemplate(oldCategoryId, categoryId) {
    if (this.get("action") !== CREATE_TOPIC) {
      return;
    }
    let reply = this.get("reply");

    // If the user didn't change the template, clear it
    if (oldCategoryId) {
      const oldCat = this.site.categories.findBy("id", oldCategoryId);
      if (oldCat && oldCat.get("topic_template") === reply) {
        reply = "";
      }
    }

    if (!Ember.isEmpty(reply)) {
      return;
    }
    const category = this.site.categories.findBy("id", categoryId);
    if (category) {
      this.set("reply", category.get("topic_template") || "");
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

    const replyBlank = Ember.isEmpty(this.get("reply"));

    const composer = this;
    if (
      !replyBlank &&
      ((opts.reply || isEdit(opts.action)) && this.get("replyDirty"))
    ) {
      return;
    }

    if (opts.action === REPLY && isEdit(this.get("action")))
      this.set("reply", "");
    if (!opts.draftKey) throw new Error("draft key is required");
    if (opts.draftSequence === null)
      throw new Error("draft sequence is required");

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
      this.set("post", opts.post);

      this.set(
        "whisper",
        opts.post.get("post_type") === this.site.get("post_types.whisper")
      );
      if (!this.get("topic")) {
        this.set("topic", opts.post.get("topic"));
      }
    } else {
      this.set("post", null);
    }

    this.setProperties({
      archetypeId: opts.archetypeId || this.site.get("default_archetype"),
      metaData: opts.metaData ? Ember.Object.create(opts.metaData) : null,
      reply: opts.reply || this.get("reply") || ""
    });

    // We set the category id separately for topic templates on opening of composer
    this.set("categoryId", opts.categoryId || this.get("topic.category.id"));

    if (!this.get("categoryId") && this.get("creatingTopic")) {
      const categories = this.site.get("categories");
      if (categories.length === 1) {
        this.set("categoryId", categories[0].get("id"));
      }
    }

    if (opts.postId) {
      this.set("loading", true);
      this.store.find("post", opts.postId).then(function(post) {
        composer.set("post", post);
        composer.set("loading", false);
      });
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

      this.store.find("post", opts.post.get("id")).then(function(post) {
        composer.setProperties({
          reply: post.get("raw"),
          originalText: post.get("raw"),
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
    this.set("originalText", opts.draft ? "" : this.get("reply"));
    if (this.get("editingFirstPost")) {
      this.set("originalTitle", this.get("title"));
    }

    if (!isEdit(opts.action) || !opts.post) {
      composer.appEvents.trigger("composer:reply-reloaded", composer);
    }

    return false;
  },

  save(opts) {
    if (!this.get("cantSubmitPost")) {
      // change category may result in some effect for topic featured link
      if (!this.get("canEditTopicFeaturedLink")) {
        this.set("featuredLink", null);
      }

      return this.get("editingPost")
        ? this.editPost(opts)
        : this.createPost(opts);
    }
  },

  /**
    Clear any state we have in preparation for a new composition.

    @method clearState
  **/
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

  // When you edit a post
  editPost(opts) {
    let post = this.get("post");
    let oldCooked = post.get("cooked");
    let promise = Ember.RSVP.resolve();

    // Update the topic if we're editing the first post
    if (
      this.get("title") &&
      post.get("post_number") === 1 &&
      this.get("topic.details.can_edit")
    ) {
      const topicProps = this.getProperties(
        Object.keys(_edit_topic_serializer)
      );

      let topic = this.get("topic");

      // If we're editing a shared draft, keep the original category
      if (this.get("action") === EDIT_SHARED_DRAFT) {
        let destinationCategoryId = topicProps.categoryId;
        promise = promise.then(() =>
          topic.updateDestinationCategory(destinationCategoryId)
        );
        topicProps.categoryId = topic.get("category.id");
      }
      promise = promise.then(() => Topic.update(topic, topicProps));
    }

    const props = {
      raw: this.get("reply"),
      raw_old: this.get("editConflict") ? null : this.get("originalText"),
      edit_reason: opts.editReason,
      image_sizes: opts.imageSizes,
      cooked: this.getCookedHtml()
    };

    this.set("composeState", SAVING);

    let rollback = throwAjaxError(error => {
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

  // Create a new Post
  createPost(opts) {
    const post = this.get("post"),
      topic = this.get("topic"),
      user = this.user,
      postStream = this.get("topic.postStream");

    let addedToStream = false;

    const postTypes = this.site.get("post_types");
    const postType = this.get("whisper")
      ? postTypes.whisper
      : postTypes.regular;

    // Build the post object
    const createdPost = this.store.createRecord("post", {
      imageSizes: opts.imageSizes,
      cooked: this.getCookedHtml(),
      reply_count: 0,
      name: user.get("name"),
      display_username: user.get("name"),
      username: user.get("username"),
      user_id: user.get("id"),
      user_title: user.get("title"),
      avatar_template: user.get("avatar_template"),
      user_custom_fields: user.get("custom_fields"),
      post_type: postType,
      actions_summary: [],
      moderator: user.get("moderator"),
      admin: user.get("admin"),
      yours: true,
      read: true,
      wiki: false,
      typingTime: this.get("typingTime"),
      composerTime: this.get("composerTime")
    });

    this.serialize(_create_serializer, createdPost);

    if (post) {
      createdPost.setProperties({
        reply_to_post_number: post.get("post_number"),
        reply_to_user: {
          username: post.get("username"),
          avatar_template: post.get("avatar_template")
        }
      });
    }

    let state = null;

    // If we're in a topic, we can append the post instantly.
    if (postStream) {
      // If it's in reply to another post, increase the reply count
      if (post) {
        post.set("reply_count", (post.get("reply_count") || 0) + 1);
        post.set("replies", []);
      }

      // We do not stage posts in mobile view, we do not have the "cooked"
      // Furthermore calculating cooked is very complicated, especially since
      // we would need to handle oneboxes and other bits that are not even in the
      // engine, staging will just cause a blank post to render
      if (!_.isEmpty(createdPost.get("cooked"))) {
        state = postStream.stagePost(createdPost, user);
        if (state === "alreadyStaging") {
          return;
        }
      }
    }

    const composer = this;
    composer.set("composeState", SAVING);
    composer.set("stagedPost", state === "staged" && createdPost);

    return createdPost
      .save()
      .then(function(result) {
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
          const category = composer.site.get("categories").find(function(x) {
            return (
              x.get("id") === (parseInt(createdPost.get("category"), 10) || 1)
            );
          });
          if (category) category.incrementProperty("topic_count");
          Discourse.notifyPropertyChange("globalNotice");
        }

        composer.clearState();
        composer.set("createdPost", createdPost);

        if (addedToStream) {
          composer.set("composeState", CLOSED);
        } else if (saving) {
          composer.set("composeState", SAVING);
        }

        return result;
      })
      .catch(
        throwAjaxError(function() {
          if (postStream) {
            postStream.undoPost(createdPost);

            if (post) {
              post.set("reply_count", post.get("reply_count") - 1);
            }
          }
          Ember.run.next(() => composer.set("composeState", OPEN));
        })
      );
  },

  getCookedHtml() {
    return $("#reply-control .d-editor-preview")
      .html()
      .replace(/<span class="marker"><\/span>/g, "");
  },

  saveDraft() {
    // Do not save when drafts are disabled
    if (this.get("disableDrafts")) return;

    if (this.get("canEditTitle")) {
      // Save title and/or post body
      if (!this.get("title") && !this.get("reply")) return;
      if (
        this.get("title") &&
        this.get("titleLengthValid") &&
        this.get("reply") &&
        this.get("replyLength") < this.siteSettings.min_post_length
      )
        return;
    } else {
      // Do not save when there is no reply
      if (!this.get("reply")) return;
      // Do not save when the reply's length is too small
      if (this.get("replyLength") < this.siteSettings.min_post_length) return;
    }

    this.setProperties({
      draftSaved: false,
      draftSaving: true,
      draftConflictUser: null
    });

    if (this._clearingStatus) {
      Ember.run.cancel(this._clearingStatus);
      this._clearingStatus = null;
    }

    const data = {
      reply: this.get("reply"),
      action: this.get("action"),
      title: this.get("title"),
      categoryId: this.get("categoryId"),
      postId: this.get("post.id"),
      archetypeId: this.get("archetypeId"),
      whisper: this.get("whisper"),
      metaData: this.get("metaData"),
      usernames: this.get("targetUsernames"),
      composerTime: this.get("composerTime"),
      typingTime: this.get("typingTime"),
      tags: this.get("tags"),
      noBump: this.get("noBump")
    };

    if (this.get("post.id") && !Ember.isEmpty(this.get("originalText"))) {
      data["originalText"] = this.get("originalText");
    }

    return Draft.save(this.get("draftKey"), this.get("draftSequence"), data)
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

  dataChanged: function() {
    const draftStatus = this.get("draftStatus");
    const self = this;

    if (draftStatus && !this._clearingStatus) {
      this._clearingStatus = Ember.run.later(
        this,
        function() {
          self.set("draftStatus", null);
          self.set("draftConflictUser", null);
          self._clearingStatus = null;
          self.set("draftSaving", false);
          self.set("draftSaved", false);
        },
        Ember.Test ? 0 : 1000
      );
    }
  }.observes("title", "reply")
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
  REPLY_AS_NEW_TOPIC_KEY,
  REPLY_AS_NEW_PRIVATE_MESSAGE_KEY
});

export default Composer;
