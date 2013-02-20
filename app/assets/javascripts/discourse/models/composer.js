
/* The status the compose view can have
*/


(function() {
  var CLOSED, CREATE_TOPIC, DRAFT, EDIT, OPEN, PRIVATE_MESSAGE, REPLY, REPLY_AS_NEW_TOPIC_KEY, SAVING;

  CLOSED = 'closed';

  SAVING = 'saving';

  OPEN = 'open';

  DRAFT = 'draft';

  /* The actions the composer can take
  */


  CREATE_TOPIC = 'createTopic';

  PRIVATE_MESSAGE = 'privateMessage';

  REPLY = 'reply';

  EDIT = 'edit';

  REPLY_AS_NEW_TOPIC_KEY = "reply_as_new_topic";

  window.Discourse.Composer = Discourse.Model.extend({
    init: function() {
      var val;
      this._super();
      val = Discourse.KeyValueStore.get('composer.showPreview') || 'true';
      this.set('showPreview', val === 'true');
      return this.set('archetypeId', Discourse.get('site.default_archetype'));
    },
    archetypesBinding: 'Discourse.site.archetypes',
    creatingTopic: (function() {
      return this.get('action') === CREATE_TOPIC;
    }).property('action'),
    creatingPrivateMessage: (function() {
      return this.get('action') === PRIVATE_MESSAGE;
    }).property('action'),
    editingPost: (function() {
      return this.get('action') === EDIT;
    }).property('action'),
    viewOpen: (function() {
      return this.get('composeState') === OPEN;
    }).property('composeState'),
    archetype: (function() {
      return this.get('archetypes').findProperty('id', this.get('archetypeId'));
    }).property('archetypeId'),
    archetypeChanged: (function() {
      return this.set('metaData', Em.Object.create());
    }).observes('archetype'),
    editTitle: (function() {
      if (this.get('creatingTopic') || this.get('creatingPrivateMessage')) {
        return true;
      }
      if (this.get('editingPost') && this.get('post.post_number') === 1) {
        return true;
      }
      return false;
    }).property('editingPost', 'creatingTopic', 'post.post_number'),
    togglePreview: function() {
      this.toggleProperty('showPreview');
      return Discourse.KeyValueStore.set({
        key: 'showPreview',
        value: this.get('showPreview')
      });
    },
    /* Import a quote from the post
    */

    importQuote: function() {
      var post, posts,
        _this = this;
      post = this.get('post');
      if (!post) {
        posts = this.get('topic.posts');
        if (posts && posts.length > 0) {
          post = posts[0];
        }
      }
      if (post) {
        this.set('loading', true);
        return Discourse.Post.load(post.get('id'), function(result) {
          var quotedText;
          quotedText = Discourse.BBCode.buildQuoteBBCode(post, result.get('raw'));
          _this.appendText(quotedText);
          return _this.set('loading', false);
        });
      }
    },
    appendText: function(text) {
      return this.set('reply', (this.get('reply') || '') + text);
    },
    /* Determine the appropriate title for this action
    */

    actionTitle: (function() {
      var postLink, postNumber, replyAvatar, topic, topicLink;
      topic = this.get('topic');
      postNumber = this.get('post.post_number');
      if (topic) {
        postLink = "<a href='" + (topic.get('url')) + "/" + postNumber + "'>post " + postNumber + "</a>";
      }
      switch (this.get('action')) {
        case PRIVATE_MESSAGE:
          return Em.String.i18n('topic.private_message');
        case CREATE_TOPIC:
          return Em.String.i18n('topic.create_long');
        case REPLY:
          if (this.get('post')) {
            replyAvatar = Discourse.Utilities.avatarImg({
              username: this.get('post.username'),
              size: 'tiny'
            });
            return Em.String.i18n('post.reply', {
              link: postLink,
              replyAvatar: replyAvatar,
              username: this.get('post.username')
            });
          } else if (topic) {
            topicLink = "<a href='" + (topic.get('url')) + "'> " + (Handlebars.Utils.escapeExpression(topic.get('title'))) + "</a>";
            return Em.String.i18n('post.reply_topic', {
              link: topicLink
            });
          }
          break;
        case EDIT:
          return Em.String.i18n('post.edit', {
            link: postLink
          });
      }
    }).property('action', 'post', 'topic', 'topic.title'),
    toggleText: (function() {
      if (this.get('showPreview')) {
        return Em.String.i18n('composer.hide_preview');
      }
      return Em.String.i18n('composer.show_preview');
    }).property('showPreview'),
    hidePreview: (function() {
      return !this.get('showPreview');
    }).property('showPreview'),
    /* Whether to disable the post button
    */

    cantSubmitPost: (function() {
      /* Can't submit while loading
      */
      if (this.get('loading')) {
        return true;
      }
      /* Title is required on new posts
      */

      if (this.get('creatingTopic')) {
        if (this.blank('title')) {
          return true;
        }
        if (this.get('title').trim().length < Discourse.SiteSettings.min_topic_title_length) {
          return true;
        }
      }
      /* Otherwise just reply is required
      */

      if (this.blank('reply')) {
        return true;
      }
      if (this.get('reply').trim().length < Discourse.SiteSettings.min_post_length) {
        return true;
      }
      return false;
    }).property('reply', 'title', 'creatingTopic', 'loading'),
    /* The text for the save button
    */

    saveText: (function() {
      switch (this.get('action')) {
        case EDIT:
          return Em.String.i18n('composer.save_edit');
        case REPLY:
          return Em.String.i18n('composer.reply');
        case CREATE_TOPIC:
          return Em.String.i18n('composer.create_topic');
        case PRIVATE_MESSAGE:
          return Em.String.i18n('composer.create_pm');
      }
    }).property('action'),
    hasMetaData: (function() {
      var metaData;
      metaData = this.get('metaData');
      if (!this.get('metaData')) {
        return false;
      }
      return Em.empty(Em.keys(this.get('metaData')));
    }).property('metaData'),
    wouldLoseChanges: function() {
      return this.get('reply') !== this.get('originalText');
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
      var replyBlank, topicId,
        _this = this;
      if (!opts) opts = {};
      
      this.set('loading', false);
      if (opts.topic) {
        topicId = opts.topic.get('id');
      }
      replyBlank = (this.get("reply") || "") === "";
      if (!replyBlank && 
          (opts.action !== this.get('action') || ((opts.reply || opts.action === this.EDIT) && this.get('reply') !== this.get('originalText'))) && 
          !opts.tested) {
        opts.tested = true;
        this.cancel(function() {
          return _this.open(opts);
        });
        return;
      }
      this.set('draftKey', opts.draftKey);
      this.set('draftSequence', opts.draftSequence);
      if (!opts.draftKey) {
        throw 'draft key is required';
      }
      if (opts.draftSequence === null) throw 'draft sequence is required';

      this.set('composeState', opts.composerState || OPEN);
      this.set('action', opts.action);
      this.set('topic', opts.topic);
      this.set('targetUsernames', opts.usernames);
      if (opts.post) {
        this.set('post', opts.post);
        if (!this.get('topic')) {
          this.set('topic', opts.post.get('topic'));
        }
      }
      this.set('categoryName', opts.categoryName || this.get('topic.category.name'));
      this.set('archetypeId', opts.archetypeId || Discourse.get('site.default_archetype'));
      this.set('metaData', opts.metaData ? Em.Object.create(opts.metaData) : null);
      this.set('reply', opts.reply || this.get("reply") || "");
      if (opts.postId) {
        this.set('loading', true);
        Discourse.Post.load(opts.postId, function(result) {
          _this.set('post', result);
          return _this.set('loading', false);
        });
      }
      /* If we are editing a post, load it.
      */

      if (opts.action === EDIT && opts.post) {
        this.set('title', this.get('topic.title'));
        this.set('loading', true);
        Discourse.Post.load(opts.post.get('id'), function(result) {
          _this.set('reply', result.get('raw'));
          _this.set('originalText', _this.get('reply'));
          return _this.set('loading', false);
        });
      }
      if (opts.title) {
        this.set('title', opts.title);
      }
      if (opts.draft) {
        this.set('originalText', '');
      } else if (opts.reply) {
        this.set('originalText', this.get('reply'));
      }
      return false;
    },
    save: function(opts) {
      if (this.get('editingPost')) {
        return this.editPost(opts);
      } else {
        return this.createPost(opts);
      }
    },
    /* When you edit a post
    */

    editPost: function(opts) {
      var oldCooked, post, promise, topic,
        _this = this;
      promise = new RSVP.Promise();
      post = this.get('post');
      oldCooked = post.get('cooked');
      /* Update the title if we've changed it
      */

      if (this.get('title') && post.get('post_number') === 1) {
        topic = this.get('topic');
        topic.set('title', this.get('title'));
        topic.set('categoryName', this.get('categoryName'));
        topic.save();
      }
      post.set('raw', this.get('reply'));
      post.set('imageSizes', opts.imageSizes);
      post.set('cooked', jQuery('#wmd-preview').html());
      this.set('composeState', CLOSED);
      post.save(function(savedPost) {
        var idx, postNumber, posts;
        posts = _this.get('topic.posts');
        /* perhaps our post came from elsewhere eg. draft
        */

        idx = -1;
        postNumber = post.get('post_number');
        posts.each(function(p, i) {
          if (p.get('post_number') === postNumber) {
            idx = i;
          }
        });
        if (idx > -1) {
          savedPost.set('topic', _this.get('topic'));
          posts.replace(idx, 1, [savedPost]);
          promise.resolve({
            post: post
          });
          _this.set('topic.draft_sequence', savedPost.draft_sequence);
        }
      }, function(error) {
        var errors;
        errors = jQuery.parseJSON(error.responseText).errors;
        promise.reject(errors[0]);
        post.set('cooked', oldCooked);
        return _this.set('composeState', OPEN);
      });
      return promise;
    },
    /* Create a new Post
    */

    createPost: function(opts) {
      var addedToStream, createdPost, diff, lastPost, post, promise, topic,
        _this = this;
      promise = new RSVP.Promise();
      post = this.get('post');
      topic = this.get('topic');
      createdPost = Discourse.Post.create({
        raw: this.get('reply'),
        title: this.get('title'),
        category: this.get('categoryName'),
        topic_id: this.get('topic.id'),
        reply_to_post_number: post ? post.get('post_number') : null,
        imageSizes: opts.imageSizes,
        post_number: this.get('topic.highest_post_number') + 1,
        cooked: jQuery('#wmd-preview').html(),
        reply_count: 0,
        display_username: Discourse.get('currentUser.name'),
        username: Discourse.get('currentUser.username'),
        metaData: this.get('metaData'),
        archetype: this.get('archetypeId'),
        post_type: Discourse.get('site.post_types.regular'),
        target_usernames: this.get('targetUsernames'),
        actions_summary: Em.A(),
        yours: true,
        newPost: true
      });
      addedToStream = false;
      /* If we're in a topic, we can append the post instantly.
      */

      if (topic) {
        /* Increase the reply count
        */

        if (post) {
          post.set('reply_count', (post.get('reply_count') || 0) + 1);
        }
        topic.set('posts_count', topic.get('posts_count') + 1);
        /* Update last post
        */

        topic.set('last_posted_at', new Date());
        topic.set('highest_post_number', createdPost.get('post_number'));
        topic.set('last_poster', Discourse.get('currentUser'));
        /* Set the topic view for the new post
        */

        createdPost.set('topic', topic);
        createdPost.set('created_at', new Date());
        /* If we're near the end of the topic, load new posts
        */

        lastPost = topic.posts.last();
        if (lastPost) {
          diff = topic.get('highest_post_number') - lastPost.get('post_number');
          /* If the new post is within a threshold of the end of the topic,
          */

          /* add it and scroll there instead of adding the link.
          */

          if (diff < 5) {
            createdPost.set('scrollToAfterInsert', createdPost.get('post_number'));
            topic.pushPosts([createdPost]);
            addedToStream = true;
          }
        }
      }
      /* Save callback
      */

      createdPost.save(function(result) {
        var addedPost, saving;
        addedPost = false;
        saving = true;
        createdPost.updateFromSave(result);
        if (topic) {
          /* It's no longer a new post
          */

          createdPost.set('newPost', false);
          topic.set('draft_sequence', result.draft_sequence);
        } else {
          /* We created a new topic, let's show it.
          */

          _this.set('composeState', CLOSED);
          saving = false;
        }
        _this.set('reply', '');
        _this.set('createdPost', createdPost);
        if (addedToStream) {
          _this.set('composeState', CLOSED);
        } else if (saving) {
          _this.set('composeState', SAVING);
        }
        return promise.resolve({
          post: result
        });
      }, function(error) {
        var errors;
        if (topic) {
          topic.posts.removeObject(createdPost);
        }
        errors = jQuery.parseJSON(error.responseText).errors;
        promise.reject(errors[0]);
        return _this.set('composeState', OPEN);
      });
      return promise;
    },
    saveDraft: function() {
      var data,
        _this = this;
      if (this.get('disableDrafts')) {
        return;
      }
      if (!this.get('reply')) {
        return;
      }
      if (this.get('reply').length < Discourse.SiteSettings.min_post_length) {
        return;
      }
      data = {
        reply: this.get('reply'),
        action: this.get('action'),
        title: this.get('title'),
        categoryName: this.get('categoryName'),
        postId: this.get('post.id'),
        archetypeId: this.get('archetypeId'),
        metaData: this.get('metaData'),
        usernames: this.get('targetUsernames')
      };
      this.set('draftStatus', Em.String.i18n('composer.saving_draft_tip'));
      return Discourse.Draft.save(this.get('draftKey'), this.get('draftSequence'), data).then((function() {
        return _this.set('draftStatus', Em.String.i18n('composer.saved_draft_tip'));
      }), (function() {
        return _this.set('draftStatus', 'drafts offline');
      }));
    },
    resetDraftStatus: (function() {
      var len, reply;
      reply = this.get('reply');
      len = Discourse.SiteSettings.min_post_length;
      if (!reply) {
        return this.set('draftStatus', Em.String.i18n('composer.min_length.at_least', {
          n: len
        }));
      } else if (reply.length < len) {
        return this.set('draftStatus', Em.String.i18n('composer.min_length.more', {
          n: len - reply.length
        }));
      } else {
        return this.set('draftStatus', null);
      }
    }).observes('reply', 'title'),
    blank: function(prop) {
      var p;
      p = this.get(prop);
      return !(p && p.length > 0);
    }
  });

  Discourse.Composer.reopenClass({
    open: function(opts) {
      var composer;
      composer = Discourse.Composer.create();
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
          categoryName: draft.categoryName,
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
    /* The status the compose view can have
    */

    CLOSED: CLOSED,
    SAVING: SAVING,
    OPEN: OPEN,
    DRAFT: DRAFT,
    /* The actions the composer can take
    */

    CREATE_TOPIC: CREATE_TOPIC,
    PRIVATE_MESSAGE: PRIVATE_MESSAGE,
    REPLY: REPLY,
    EDIT: EDIT,
    /* Draft key
    */

    REPLY_AS_NEW_TOPIC_KEY: REPLY_AS_NEW_TOPIC_KEY
  });

}).call(this);
