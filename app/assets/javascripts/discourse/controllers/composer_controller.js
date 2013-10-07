/**
  This controller supports composing new posts and topics.

  @class ComposerController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.ComposerController = Discourse.Controller.extend({
  needs: ['modal', 'topic', 'composerMessages'],

  replyAsNewTopicDraft: Em.computed.equal('model.draftKey', Discourse.Composer.REPLY_AS_NEW_TOPIC_KEY),
  checkedMessages: false,

  init: function() {
    this._super();
    this.set('similarTopics', Em.A());
  },

  actions: {
    // Toggle the reply view
    toggle: function() {
      this.toggle();
    },

    togglePreview: function() {
      this.get('model').togglePreview();
    },

    // Import a quote from the post
    importQuote: function() {
      this.get('model').importQuote();
    },

    cancel: function() {
      this.cancelComposer();
    },

    save: function() {
      this.save();
    }
  },

  updateDraftStatus: function() {
    this.get('model').updateDraftStatus();
  },

  appendText: function(text) {
    var c = this.get('model');
    if (c) { c.appendText(text); }
  },

  categories: function() {
    return Discourse.Category.list();
  }.property(),


  toggle: function() {
    this.closeAutocomplete();
    switch (this.get('model.composeState')) {
      case Discourse.Composer.OPEN:
        if (this.blank('model.reply') && this.blank('model.title')) {
          this.close();
        } else {
          this.shrink();
        }
        break;
      case Discourse.Composer.DRAFT:
        this.set('model.composeState', Discourse.Composer.OPEN);
        break;
      case Discourse.Composer.SAVING:
        this.close();
    }
    return false;
  },

  save: function(force) {
    var composer = this.get('model'),
        composerController = this;

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
      var topic = this.get('topic');
      if (!topic || topic.get('id') !== composer.get('topic.id'))
      {
        var message = I18n.t("composer.posting_not_on_topic", {title: this.get('model.topic.title')});

        var buttons = [{
          "label": I18n.t("composer.cancel"),
          "class": "cancel",
          "link": true
        }];

        if(topic) {
          buttons.push({
            "label": I18n.t("composer.reply_here") + "<br/><div class='topic-title overflow-ellipsis'>" + topic.get('title') + "</div>",
            "class": "btn btn-reply-here",
            "callback": function(){
              composer.set('topic', topic);
              composer.set('post', null);
              composerController.save(true);
            }
          });
        }

        buttons.push({
          "label": I18n.t("composer.reply_original") + "<br/><div class='topic-title overflow-ellipsis'>" + this.get('model.topic.title') + "</div>",
          "class": "btn-primary btn-reply-on-original",
          "callback": function(){
            composerController.save(true);
          }
        });

        bootbox.dialog(message, buttons, {"classes": "reply-where-modal"});
        return;
      }
    }

    return composer.save({
      imageSizes: this.get('view').imageSizes()
    }).then(function(opts) {

      // If we replied as a new topic successfully, remove the draft.
      if (composerController.get('replyAsNewTopicDraft')) {
        composerController.destroyDraft();
      }

      opts = opts || {};
      composerController.close();

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

  /**
    Checks to see if a reply has been typed. This is signaled by a keyUp
    event in a view.

    @method checkReplyLength
  **/
  checkReplyLength: function() {
    if (this.present('model.reply')) {
      // Notify the composer messages controller that a reply has been typed. Some
      // messages only appear after typing.
      this.get('controllers.composerMessages').typedReply();
    }
  },

  /**
    Fired after a user stops typing. Considers whether to check for similar
    topics based on the current composer state.

    @method findSimilarTopics
  **/
  findSimilarTopics: function() {

    // We don't care about similar topics unless creating a topic
    if (!this.get('model.creatingTopic')) return;

    var body = this.get('model.reply'),
        title = this.get('model.title');

    // Ensure the fields are of the minimum length
    if (body.length < Discourse.SiteSettings.min_body_similar_length ||
        title.length < Discourse.SiteSettings.min_title_similar_length) { return; }

    var messageController = this.get('controllers.composerMessages'),
        similarTopics = this.get('similarTopics');

    Discourse.Topic.findSimilarTo(title, body).then(function (newTopics) {
      similarTopics.clear();
      similarTopics.pushObjects(newTopics);

      if (similarTopics.get('length') > 0) {
        messageController.popup(Discourse.ComposerMessage.create({
          templateName: 'composer/similar_topics',
          similarTopics: similarTopics,
          extraClass: 'similar-topics'
        }));
      }
    });

  },

  saveDraft: function() {
    var model = this.get('model');
    if (model) { model.saveDraft(); }
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

    var composerMessages = this.get('controllers.composerMessages');
    composerMessages.reset();

    var promise = opts.promise || Ember.Deferred.create();
    opts.promise = promise;

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

    var composer = this.get('model');
    if (composer && opts.draftKey !== composer.draftKey && composer.composeState === Discourse.Composer.DRAFT) {
      this.close();
      composer = null;
    }

    if (composer && !opts.tested && composer.get('replyDirty')) {
      if (composer.composeState === Discourse.Composer.DRAFT && composer.draftKey === opts.draftKey && composer.action === opts.action) {
        composer.set('composeState', Discourse.Composer.OPEN);
        promise.resolve();
        return promise;
      } else {
        opts.tested = true;
        if (!opts.ignoreIfChanged) {
          this.cancelComposer().then(function() { composerController.open(opts); },
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

    composer = composer || Discourse.Composer.create();
    composer.open(opts);

    this.set('model', composer);
    composer.set('composeState', Discourse.Composer.OPEN);
    composerMessages.queryFor(this.get('model'));
    promise.resolve();
    return promise;
  },

  // View a new reply we've made
  viewNewReply: function() {
    Discourse.URL.routeTo(this.get('createdPost.url'));
    this.close();
    return false;
  },

  destroyDraft: function() {
    var key = this.get('model.draftKey');
    if (key) {
      Discourse.Draft.clear(key, this.get('model.draftSequence'));
    }
  },

  cancelComposer: function() {
    var composerController = this;

    return Ember.Deferred.promise(function (promise) {
      if (composerController.get('model.hasMetaData') || composerController.get('model.replyDirty')) {
        bootbox.confirm(I18n.t("post.abandon"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
          if (result) {
            composerController.destroyDraft();
            composerController.get('model').clearState();
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
    if (this.get('model.viewDraft')) {
      this.set('model.composeState', Discourse.Composer.OPEN);
    }
  },

  shrink: function() {
    if (this.get('model.replyDirty')) {
      this.collapse();
    } else {
      this.close();
    }
  },

  collapse: function() {
    this.saveDraft();
    this.set('model.composeState', Discourse.Composer.DRAFT);
  },

  close: function() {
    this.set('model', null);
    this.set('view.showTitleTip', false);
    this.set('view.showCategoryTip', false);
    this.set('view.showReplyTip', false);
  },

  closeAutocomplete: function() {
    $('#wmd-input').autocomplete({ cancel: true });
  },

  // ESC key hit
  hitEsc: function() {
    if (this.get('model.viewOpen')) {
      this.shrink();
    }
  },

  showOptions: function() {
    var _ref;
    return (_ref = this.get('controllers.modal')) ? _ref.show(Discourse.ArchetypeOptionsModalView.create({
      archetype: this.get('model.archetype'),
      metaData: this.get('model.metaData')
    })) : void 0;
  }
});


