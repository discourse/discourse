/**
  This controller supports composing new posts and topics.

  @class ComposerController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.ComposerController = Discourse.Controller.extend({
  needs: ['modal', 'topic'],

  togglePreview: function() {
    this.get('content').togglePreview();
  },

  // Import a quote from the post
  importQuote: function() {
    this.get('content').importQuote();
  },

  updateDraftStatus: function() {
    this.get('content').updateDraftStatus();
  },

  appendText: function(text) {
    var c = this.get('content');
    if (c) return c.appendText(text);
  },

  categories: function() {
    return Discourse.Category.list();
  }.property(),

  save: function(force) {
    var composer,
      _this = this,
      topic,
      message,
      buttons;

    composer = this.get('content');

    if( composer.get('cantSubmitPost') ) {
      this.set('view.showTitleTip', Date.now());
      this.set('view.showCategoryTip', Date.now());
      this.set('view.showReplyTip', Date.now());
      return;
    }

    composer.set('disableDrafts', true);

    // for now handle a very narrow use case
    // if we are replying to a topic AND not on the topic pop the window up

    if(!force && composer.get('replyingToTopic')) {
      topic = this.get('topic');
      if (!topic || topic.get('id') !== composer.get('topic.id'))
      {
        message = Em.String.i18n("composer.posting_not_on_topic", {title: this.get('content.topic.title')});

        buttons = [{
          "label": Em.String.i18n("composer.cancel"),
          "class": "btn"
        }];

        buttons.push({
          "label": Em.String.i18n("composer.reply_original"),
          "class": "btn-primary",
          "callback": function(){
            _this.save(true);
          }
        });

        if(topic) {
          buttons.push({
            "label": Em.String.i18n("composer.reply_here"),
            "class": "btn-primary",
            "callback": function(){
              composer.set('topic', topic);
              composer.set('post', null);
              _this.save(true);
            }
          });
        }

        bootbox.dialog(message, buttons);
        return;
      }
    }

    return composer.save({
      imageSizes: this.get('view').imageSizes()
    }).then(function(opts) {
      opts = opts || {};
      _this.close();

      var currentUser = Discourse.User.current();
      if (composer.get('creatingTopic')) {
        currentUser.set('topic_count', currentUser.get('topic_count') + 1);
      } else {
        currentUser.set('reply_count', currentUser.get('reply_count') + 1);
      }
      Discourse.URL.routeTo(opts.post.get('url'));
    }, function(error) {
      composer.set('disableDrafts', false);
      bootbox.alert(error);
    });
  },

  closeEducation: function() {
    this.set('educationClosed', true);
  },

  closeSimilar: function() {
    this.set('similarClosed', true);
  },

  similarVisible: function() {
    if (this.get('similarClosed')) return false;
    if (this.get('content.composeState') !== Discourse.Composer.OPEN) return false;
    return (this.get('similarTopics.length') || 0) > 0;
  }.property('similarTopics.length', 'similarClosed', 'content.composeState'),

  newUserEducationVisible: function() {
    if (!this.get('educationContents')) return false;
    if (this.get('content.composeState') !== Discourse.Composer.OPEN) return false;
    if (!this.present('content.reply')) return false;
    if (this.get('educationClosed')) return false;
    return true;
  }.property('content.composeState', 'content.reply', 'educationClosed', 'educationContents'),

  fetchNewUserEducation: function() {

    // We don't show education when editing a post.
    if (this.get('content.editingPost')) return;

    // If creating a topic, use topic_count, otherwise post_count
    var count = this.get('content.creatingTopic') ? Discourse.User.current('topic_count') : Discourse.User.current('reply_count');
    if (count >= Discourse.SiteSettings.educate_until_posts) {
      this.set('educationClosed', true);
      this.set('educationContents', '');
      return;
    }

    // The user must have typed a reply
    if (!this.get('typedReply')) return;

    this.set('educationClosed', false);

    // If visible update the text
    var educationKey = this.get('content.creatingTopic') ? 'new-topic' : 'new-reply';
    var composerController = this;
    Discourse.ajax("/education/" + educationKey, {dataType: 'html'}).then(function(result) {
      composerController.set('educationContents', result);
    });

  }.observes('typedReply', 'content.creatingTopic', 'currentUser.reply_count'),

  checkReplyLength: function() {
    this.set('typedReply', this.present('content.reply'));
  },

  /**
    Fired after a user stops typing. Considers whether to check for similar
    topics based on the current composer state.

    @method findSimilarTopics
  **/
  findSimilarTopics: function() {

    // We don't care about similar topics unless creating a topic
    if (!this.get('content.creatingTopic')) return;

    var body = this.get('content.reply');
    var title = this.get('content.title');

    // Ensure the fields are of the minimum length
    if (body.length < Discourse.SiteSettings.min_body_similar_length) return;
    if (title.length < Discourse.SiteSettings.min_title_similar_length) return;

    var composerController = this;
    Discourse.Topic.findSimilarTo(title, body).then(function (topics) {
      composerController.set('similarTopics', topics);
    });

  },

  saveDraft: function() {
    var model = this.get('content');
    if (model) model.saveDraft();
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
  open: function(opts) {
    if (!opts) opts = {};
    var promise = opts.promise || Ember.Deferred.create();
    opts.promise = promise;
    this.set('typedReply', false);
    this.set('similarTopics', null);
    this.set('similarClosed', false);

    if (!opts.draftKey) {
      alert("composer was opened without a draft key");
      throw "composer opened without a proper draft key";
    }

    // ensure we have a view now, without it transitions are going to be messed
    var view = this.get('view');
    var composerController = this;
    if (!view) {

      // TODO: We should refactor how composer is inserted. It should probably use a
      // {{render}} and then the controller and view will be wired up automatically.
      var appView = Discourse.__container__.lookup('view:application');
      view = appView.createChildView(Discourse.ComposerView, {controller: this});
      view.appendTo($('#main'));
      this.set('view', view);

      // the next runloop is too soon, need to get the control rendered and then
      //  we need to change stuff, otherwise css animations don't kick in
      Em.run.next(function() {
        Em.run.next(function() {
          composerController.open(opts);
        });
      });
      return promise;
    }

    var composer = this.get('content');
    if (composer && opts.draftKey !== composer.draftKey && composer.composeState === Discourse.Composer.DRAFT) {
      this.close();
      composer = null;
    }

    if (composer && !opts.tested && composer.wouldLoseChanges()) {
      if (composer.composeState === Discourse.Composer.DRAFT && composer.draftKey === opts.draftKey && composer.action === opts.action) {
        composer.set('composeState', Discourse.Composer.OPEN);
        promise.resolve();
        return promise;
      } else {
        opts.tested = true;
        if (!opts.ignoreIfChanged) {
          this.cancel().then(function() { composerController.open(opts); },
                             function() { return promise.reject(); });
        }
        return promise;
      }
    }

    // we need a draft sequence, without it drafts are bust
    if (opts.draftSequence === void 0) {
      Discourse.Draft.get(opts.draftKey).then(function(data) {
        opts.draftSequence = data.draft_sequence;
        opts.draft = data.draft;
        return composerController.open(opts);
      });
      return promise;
    }

    if (opts.draft) {
      composer = Discourse.Composer.loadDraft(opts.draftKey, opts.draftSequence, opts.draft);
      if (composer) {
        composer.set('topic', opts.topic);
      }
    }

    composer = composer || Discourse.Composer.open(opts);
    this.set('content', composer);
    this.set('view.content', composer);
    promise.resolve();
    return promise;
  },

  wouldLoseChanges: function() {
    var composer = this.get('content');
    return composer && composer.wouldLoseChanges();
  },

  // View a new reply we've made
  viewNewReply: function() {
    Discourse.URL.routeTo(this.get('createdPost.url'));
    this.close();
    return false;
  },

  destroyDraft: function() {
    var key = this.get('content.draftKey');
    if (key) {
      Discourse.Draft.clear(key, this.get('content.draftSequence'));
    }
  },

  cancel: function() {
    var composerController = this;
    return Ember.Deferred.promise(function (promise) {
      if (composerController.get('content.hasMetaData') ||
          ((composerController.get('content.reply') || "") !== (composerController.get('content.originalText') || ""))) {
        bootbox.confirm(Em.String.i18n("post.abandon"), Em.String.i18n("no_value"), Em.String.i18n("yes_value"), function(result) {
          if (result) {
            composerController.destroyDraft();
            composerController.close();
            promise.resolve();
          } else {
            promise.reject();
          }
        });
      } else {
        // it is possible there is some sort of crazy draft with no body ... just give up on it
        composerController.destroyDraft();
        composerController.close();
        promise.resolve();
      }
    });
  },

  openIfDraft: function() {
    if (this.get('content.composeState') === Discourse.Composer.DRAFT) {
      this.set('content.composeState', Discourse.Composer.OPEN);
    }
  },

  shrink: function() {
    if (this.get('content.reply') === this.get('content.originalText')) {
      this.close();
    } else {
      this.collapse();
    }
  },

  collapse: function() {
    this.saveDraft();
    this.set('content.composeState', Discourse.Composer.DRAFT);
  },

  close: function() {
    this.set('content', null);
    this.set('view.content', null);
    this.set('view.showTitleTip', false);
    this.set('view.showCategoryTip', false);
    this.set('view.showReplyTip', false);
  },

  closeIfCollapsed: function() {
    if (this.get('content.composeState') === Discourse.Composer.DRAFT) {
      this.close();
    }
  },

  closeAutocomplete: function() {
    $('#wmd-input').autocomplete({ cancel: true });
  },

  // Toggle the reply view
  toggle: function() {
    this.closeAutocomplete();
    switch (this.get('content.composeState')) {
      case Discourse.Composer.OPEN:
        if (this.blank('content.reply') && this.blank('content.title')) {
          this.close();
        } else {
          this.shrink();
        }
        break;
      case Discourse.Composer.DRAFT:
        this.set('content.composeState', Discourse.Composer.OPEN);
        break;
      case Discourse.Composer.SAVING:
        this.close();
    }
    return false;
  },

  // ESC key hit
  hitEsc: function() {
    if (this.get('content.composeState') === Discourse.Composer.OPEN) {
      this.shrink();
    }
  },

  showOptions: function() {
    var _ref;
    return (_ref = this.get('controllers.modal')) ? _ref.show(Discourse.ArchetypeOptionsModalView.create({
      archetype: this.get('content.archetype'),
      metaData: this.get('content.metaData')
    })) : void 0;
  }
});


