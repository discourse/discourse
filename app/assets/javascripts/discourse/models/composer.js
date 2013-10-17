/**
  A data model for representing the composer's current state

  @class Composer
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/

var CLOSED = 'closed',
    SAVING = 'saving',
    OPEN = 'open',
    DRAFT = 'draft',

    // The actions the composer can take
    CREATE_TOPIC = 'createTopic',
    PRIVATE_MESSAGE = 'privateMessage',
    REPLY = 'reply',
    EDIT = 'edit',
    REPLY_AS_NEW_TOPIC_KEY = "reply_as_new_topic";

Discourse.Composer = Discourse.Model.extend({

  archetypes: function() {
    return Discourse.Site.currentProp('archetypes');
  }.property(),

  creatingTopic: Em.computed.equal('action', CREATE_TOPIC),
  creatingPrivateMessage: Em.computed.equal('action', PRIVATE_MESSAGE),
  notCreatingPrivateMessage: Em.computed.not('creatingPrivateMessage'),

  privateMessage: function(){
    return this.get('creatingPrivateMessage') || this.get('topic.archetype') === 'private_message';
  }.property('creatingPrivateMessage', 'topic'),

  editingPost: Em.computed.equal('action', EDIT),
  replyingToTopic: Em.computed.equal('action', REPLY),

  viewOpen: Em.computed.equal('composeState', OPEN),
  viewDraft: Em.computed.equal('composeState', DRAFT),


  archetype: function() {
    return this.get('archetypes').findProperty('id', this.get('archetypeId'));
  }.property('archetypeId'),

  archetypeChanged: function() {
    return this.set('metaData', Em.Object.create());
  }.observes('archetype'),

  editingFirstPost: Em.computed.and('editingPost', 'post.firstPost'),
  canEditTitle: Em.computed.or('creatingTopic', 'creatingPrivateMessage', 'editingFirstPost'),
  canCategorize: Em.computed.and('canEditTitle', 'notCreatingPrivateMessage'),

  showAdminOptions: function() {
    if (this.get('creatingTopic') && Discourse.User.currentProp('staff')) return true;
    return false;
  }.property('canEditTitle'),

  // Determine the appropriate title for this action
  actionTitle: function() {
    var topic = this.get('topic');

    var postLink, topicLink;
    if (topic) {
      var postNumber = this.get('post.post_number');
      postLink = "<a href='" + (topic.get('url')) + "/" + postNumber + "'>" +
        I18n.t("post.post_number", { number: postNumber }) + "</a>";
      topicLink = "<a href='" + (topic.get('url')) + "'> " + (Handlebars.Utils.escapeExpression(topic.get('title'))) + "</a>";
    }

    var postDescription,
        post = this.get('post');

    if (post) {
      postDescription = I18n.t('post.' +  this.get('action'), {
        link: postLink,
        replyAvatar: Discourse.Utilities.tinyAvatar(post.get('avatar_template')),
        username: this.get('post.username')
      });

      var replyUsername = post.get('reply_to_user.username');
      var replyAvatarTemplate = post.get('reply_to_user.avatar_template');
      if (replyUsername && replyAvatarTemplate && this.get('action') === EDIT) {
        postDescription += " " + I18n.t("post.in_reply_to") + " " + Discourse.Utilities.tinyAvatar(replyAvatarTemplate) + " " + replyUsername;
      }
    }

    switch (this.get('action')) {
      case PRIVATE_MESSAGE: return I18n.t('topic.private_message');
      case CREATE_TOPIC: return I18n.t('topic.create_long');
      case REPLY:
      case EDIT:
        if (postDescription) return postDescription;
        if (topic) return I18n.t('post.reply_topic', { link: topicLink });
    }

  }.property('action', 'post', 'topic', 'topic.title'),

  toggleText: function() {
    return this.get('showPreview') ? I18n.t('composer.hide_preview') : I18n.t('composer.show_preview');
  }.property('showPreview'),

  hidePreview: Em.computed.not('showPreview'),

  // Whether to disable the post button
  cantSubmitPost: function() {

    // Can't submit while loading
    if (this.get('loading')) return true;

    // Title is required when:
    //    - creating a new topic
    //    - editing the 1st post
    //    - creating a private message

    if (this.get('canEditTitle') && !this.get('titleLengthValid')) return true;

    // Need at least one user when sending a private message
    if ( this.get('creatingPrivateMessage') &&
         this.get('targetUsernames') &&
        (this.get('targetUsernames').trim() + ',').indexOf(',') === 0) {
      return true;
    }

    // reply is always required
    if (this.get('missingReplyCharacters') > 0) return true;

    if (this.get('canCategorize') && !Discourse.SiteSettings.allow_uncategorized_topics && !this.get('categoryId')) return true;

    return false;
  }.property('loading', 'canEditTitle', 'titleLength', 'targetUsernames', 'replyLength', 'categoryId', 'missingReplyCharacters'),

  /**
    Is the title's length valid?

    @property titleLengthValid
  **/
  titleLengthValid: function() {
    if (this.get('titleLength') < this.get('minimumTitleLength')) return false;
    return (this.get('titleLength') <= Discourse.SiteSettings.max_topic_title_length);
  }.property('minimumTitleLength', 'titleLength'),

  // The text for the save button
  saveText: function() {
    switch (this.get('action')) {
      case EDIT: return I18n.t('composer.save_edit');
      case REPLY: return I18n.t('composer.reply');
      case CREATE_TOPIC: return I18n.t('composer.create_topic');
      case PRIVATE_MESSAGE: return I18n.t('composer.create_pm');
    }
  }.property('action'),

  hasMetaData: function() {
    var metaData = this.get('metaData');
    return metaData ? Em.isEmpty(Em.keys(this.get('metaData'))) : false;
  }.property('metaData'),

  /**
    Did the user make changes to the reply?

    @property replyDirty
  **/
  replyDirty: function() {
    return this.get('reply') !== this.get('originalText');
  }.property('reply', 'originalText'),

/**
    Number of missing characters in the title until valid.

    @property missingTitleCharacters
  **/
  missingTitleCharacters: function() {
    return this.get('minimumTitleLength') - this.get('titleLength');
  }.property('minimumTitleLength', 'titleLength'),

  /**
    Minimum number of characters for a title to be valid.

    @property minimumTitleLength
  **/
  minimumTitleLength: function() {
    if (this.get('privateMessage')) {
      return Discourse.SiteSettings.min_private_message_title_length;
    } else {
      return Discourse.SiteSettings.min_topic_title_length;
    }
  }.property('privateMessage'),

  /**
    Number of missing characters in the reply until valid.

    @property missingReplyCharacters
  **/
  missingReplyCharacters: function() {
    return this.get('minimumPostLength') - this.get('replyLength');
  }.property('minimumPostLength', 'replyLength'),

  /**
    Minimum number of characters for a post body to be valid.

    @property minimumPostLength
  **/
  minimumPostLength: function() {
    if( this.get('privateMessage') ) {
      return Discourse.SiteSettings.min_private_message_post_length;
    } else {
      return Discourse.SiteSettings.min_post_length;
    }
  }.property('privateMessage'),

  /**
    Computes the length of the title minus non-significant whitespaces

    @property titleLength
  **/
  titleLength: function() {
    var title = this.get('title') || "";
    return title.replace(/\s+/img, " ").trim().length;
  }.property('title'),

  /**
    Computes the length of the reply minus the quote(s) and non-significant whitespaces

    @property replyLength
  **/
  replyLength: function() {
    var reply = this.get('reply') || "";
    while (Discourse.Quote.REGEXP.test(reply)) { reply = reply.replace(Discourse.Quote.REGEXP, ""); }
    return reply.replace(/\s+/img, " ").trim().length;
  }.property('reply'),


  updateDraftStatus: function() {
    var $title = $('#reply-title'),
        $reply = $('#wmd-input');

    // 'title' is focused
    if ($title.is(':focus')) {
      var titleDiff = this.get('missingTitleCharacters');
      if (titleDiff > 0) {
        this.flashDraftStatusForNewUser();
        return this.set('draftStatus', I18n.t('composer.min_length.need_more_for_title', { n: titleDiff }));
      }
    // 'reply' is focused
    } else if ($reply.is(':focus')) {
      var replyDiff = this.get('missingReplyCharacters');
      if (replyDiff > 0) {
        return this.set('draftStatus', I18n.t('composer.min_length.need_more_for_reply', { n: replyDiff }));
      }
    }

    // hide the counters if the currently focused text field is OK
    this.set('draftStatus', null);

  }.observes('missingTitleCharacters', 'missingReplyCharacters'),

  init: function() {
    this._super();
    var val = (Discourse.Mobile.mobileView ? false : (Discourse.KeyValueStore.get('composer.showPreview') || 'true'));
    this.set('showPreview', val === 'true');
    this.set('archetypeId', Discourse.Site.currentProp('default_archetype'));
  },

  /**
    Append text to the current reply

    @method appendText
    @param {String} text the text to append
  **/
  appendText: function(text) {
    this.set('reply', (this.get('reply') || '') + text);
  },

  togglePreview: function() {
    this.toggleProperty('showPreview');
    Discourse.KeyValueStore.set({ key: 'composer.showPreview', value: this.get('showPreview') });
  },

  importQuote: function() {
    // If there is no current post, use the post id from the stream
    var postId = this.get('post.id') || this.get('topic.postStream.firstPostId');
    if (postId) {
      this.set('loading', true);
      var composer = this;
      return Discourse.Post.load(postId).then(function(post) {
        composer.appendText(Discourse.Quote.build(post, post.get('raw')));
        composer.set('loading', false);
      });
    }
  },

  /*
     Open a composer

     opts:
       action   - The action we're performing: edit, reply or createTopic
       post     - The post we're replying to, if present
       topic   - The topic we're replying to, if present
       quote    - If we're opening a reply from a quote, the quote we're making
  */
  open: function(opts) {
    if (!opts) opts = {};
    this.set('loading', false);

    var replyBlank = Em.isEmpty(this.get("reply"));

    var composer = this;
    if (!replyBlank &&
        (opts.action !== this.get('action') || ((opts.reply || opts.action === this.EDIT) && this.get('reply') !== this.get('originalText'))) &&
        !opts.tested) {
      opts.tested = true;
      return;
    }

    if (!opts.draftKey) throw 'draft key is required';
    if (opts.draftSequence === null) throw 'draft sequence is required';

    this.setProperties({
      draftKey: opts.draftKey,
      draftSequence: opts.draftSequence,
      composeState: opts.composerState || OPEN,
      action: opts.action,
      topic: opts.topic,
      targetUsernames: opts.usernames
    });

    if (opts.post) {
      this.set('post', opts.post);
      if (!this.get('topic')) {
        this.set('topic', opts.post.get('topic'));
      }
    }

    this.setProperties({
      categoryId: opts.categoryId || this.get('topic.category.id'),
      archetypeId: opts.archetypeId || Discourse.Site.currentProp('default_archetype'),
      metaData: opts.metaData ? Em.Object.create(opts.metaData) : null,
      reply: opts.reply || this.get("reply") || ""
    });

    if (opts.postId) {
      this.set('loading', true);
      Discourse.Post.load(opts.postId).then(function(result) {
        composer.set('post', result);
        composer.set('loading', false);
      });
    }

    // If we are editing a post, load it.
    if (opts.action === EDIT && opts.post) {
      this.setProperties({
        title: this.get('topic.title'),
        loading: true
      });

      Discourse.Post.load(opts.post.get('id')).then(function(result) {
        composer.setProperties({
          reply: result.get('raw'),
          originalText: result.get('raw'),
          loading: false
        });
      });
    }
    if (opts.title) { this.set('title', opts.title); }
    this.set('originalText', opts.draft ? '' : this.get('reply'));

    return false;
  },

  save: function(opts) {
    if( !this.get('cantSubmitPost') ) {
      return this.get('editingPost') ? this.editPost(opts) : this.createPost(opts);
    }
  },

  /**
    Clear any state we have in preparation for a new composition.

    @method clearState
  **/
  clearState: function() {
    this.setProperties({
      originalText: null,
      reply: null,
      post: null,
      title: null
    });
  },

  // When you edit a post
  editPost: function(opts) {
    var post = this.get('post'),
        oldCooked = post.get('cooked'),
        composer = this;

    // Update the title if we've changed it
    if (this.get('title') && post.get('post_number') === 1) {
      var topic = this.get('topic');
      topic.setProperties({
        title: this.get('title'),
        fancy_title: this.get('title'),
        category_id: parseInt(this.get('categoryId'), 10)
      });
      topic.save();
    }

    post.setProperties({
      raw: this.get('reply'),
      imageSizes: opts.imageSizes,
      cooked: $('#wmd-preview').html()
    });
    this.set('composeState', CLOSED);

    return Ember.Deferred.promise(function(promise) {
      post.save(function(savedPost) {
        composer.clearState();
      }, function(error) {
        var response = $.parseJSON(error.responseText);
        if (response && response.errors) {
          promise.reject(response.errors[0]);
        } else {
          promise.reject(I18n.t('generic_error'));
        }
        post.set('cooked', oldCooked);
        composer.set('composeState', OPEN);
      });
    });
  },

  // Create a new Post
  createPost: function(opts) {
    var post = this.get('post'),
        topic = this.get('topic'),
        currentUser = Discourse.User.current(),
        postStream = this.get('topic.postStream'),
        addedToStream = false;


    // Build the post object
    var createdPost = Discourse.Post.create({
      raw: this.get('reply'),
      title: this.get('title'),
      category: this.get('categoryId'),
      topic_id: this.get('topic.id'),
      reply_to_post_number: post ? post.get('post_number') : null,
      imageSizes: opts.imageSizes,
      cooked: $('#wmd-preview').html(),
      reply_count: 0,
      display_username: currentUser.get('name'),
      username: currentUser.get('username'),
      user_id: currentUser.get('id'),
      metaData: this.get('metaData'),
      archetype: this.get('archetypeId'),
      post_type: Discourse.Site.currentProp('post_types.regular'),
      target_usernames: this.get('targetUsernames'),
      actions_summary: Em.A(),
      moderator: currentUser.get('moderator'),
      yours: true,
      newPost: true,
      auto_close_days: this.get('auto_close_days')
    });

    // If we're in a topic, we can append the post instantly.
    if (postStream) {
      // If it's in reply to another post, increase the reply count
      if (post) {
        post.set('reply_count', (post.get('reply_count') || 0) + 1);
      }
      if (!postStream.stagePost(createdPost, currentUser)) {

        // If we can't stage the post, return and don't save. We're likely currently
        // staging a post.
        return;
      }
    }

    var composer = this;
    return Ember.Deferred.promise(function(promise) {

      composer.set('composeState', SAVING);
      createdPost.save(function(result) {
        var addedPost = false,
            saving = true;

        createdPost.updateFromJson(result);

        if (topic) {
          // It's no longer a new post
          createdPost.set('newPost', false);
          topic.set('draft_sequence', result.draft_sequence);
          postStream.commitPost(createdPost);
          addedToStream = true;
        } else {
          // We created a new topic, let's show it.
          composer.set('composeState', CLOSED);
          saving = false;
        }

        composer.clearState();
        composer.set('createdPost', createdPost);

        if (addedToStream) {
          composer.set('composeState', CLOSED);
        } else if (saving) {
          composer.set('composeState', SAVING);
        }

        return promise.resolve({ post: result });
      }, function(error) {
        // If an error occurs
        if (postStream) {
          postStream.undoPost(createdPost);
        }
        composer.set('composeState', OPEN);
        // TODO extract error handling code
        var parsedError;
        try {
          parsedError = $.parseJSON(error.responseText).errors[0];
        }
        catch(ex) {
          parsedError = "Unknown error saving post, try again. Error: " + error.status + " " + error.statusText;
        }
        promise.reject(parsedError);
      });
    });
  },

  saveDraft: function() {
    // Do not save when drafts are disabled
    if (this.get('disableDrafts')) return;
    // Do not save when there is no reply
    if (!this.get('reply')) return;
    // Do not save when the reply's length is too small
    if (this.get('replyLength') < Discourse.SiteSettings.min_post_length) return;

    var data = {
      reply: this.get('reply'),
      action: this.get('action'),
      title: this.get('title'),
      categoryId: this.get('categoryId'),
      postId: this.get('post.id'),
      archetypeId: this.get('archetypeId'),
      metaData: this.get('metaData'),
      usernames: this.get('targetUsernames')
    };

    this.set('draftStatus', I18n.t('composer.saving_draft_tip'));

    var composer = this;

    // try to save the draft
    return Discourse.Draft.save(this.get('draftKey'), this.get('draftSequence'), data)
      .then(function() {
        composer.set('draftStatus', I18n.t('composer.saved_draft_tip'));
      }, function() {
        composer.set('draftStatus', I18n.t('composer.drafts_offline'));
      });
  },

  flashDraftStatusForNewUser: function() {
    var $draftStatus = $('#draft-status');
    if (Discourse.User.currentProp('trust_level') === 0) {
      $draftStatus.toggleClass('flash', true);
      setTimeout(function() { $draftStatus.removeClass('flash'); }, 250);
    }
  }

});

Discourse.Composer.reopenClass({

  open: function(opts) {
    var composer = Discourse.Composer.create();
    composer.open(opts);
    return composer;
  },

  loadDraft: function(draftKey, draftSequence, draft, topic) {
    var composer;
    try {
      if (draft && typeof draft === 'string') {
        draft = JSON.parse(draft);
      }
    } catch (error) {
      draft = null;
      Discourse.Draft.clear(draftKey, draftSequence);
    }
    if (draft && ((draft.title && draft.title !== '') || (draft.reply && draft.reply !== ''))) {
      composer = this.open({
        draftKey: draftKey,
        draftSequence: draftSequence,
        topic: topic,
        action: draft.action,
        title: draft.title,
        categoryId: draft.categoryId,
        postId: draft.postId,
        archetypeId: draft.archetypeId,
        reply: draft.reply,
        metaData: draft.metaData,
        usernames: draft.usernames,
        draft: true,
        composerState: DRAFT
      });
    }
    return composer;
  },

  // The status the compose view can have
  CLOSED: CLOSED,
  SAVING: SAVING,
  OPEN: OPEN,
  DRAFT: DRAFT,

  // The actions the composer can take
  CREATE_TOPIC: CREATE_TOPIC,
  PRIVATE_MESSAGE: PRIVATE_MESSAGE,
  REPLY: REPLY,
  EDIT: EDIT,

  // Draft key
  REPLY_AS_NEW_TOPIC_KEY: REPLY_AS_NEW_TOPIC_KEY
});
