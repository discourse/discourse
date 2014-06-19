/**
  This controller supports composing new posts and topics.

  @class ComposerController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
export default Discourse.Controller.extend({
  needs: ['modal', 'topic', 'composer-messages'],

  replyAsNewTopicDraft: Em.computed.equal('model.draftKey', Discourse.Composer.REPLY_AS_NEW_TOPIC_KEY),
  checkedMessages: false,

  showEditReason: false,
  editReason: null,

  _initializeSimilar: function() {
    this.set('similarTopics', []);
  }.on('init'),

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
    },

    displayEditReason: function() {
      this.set("showEditReason", true);
    },

    hitEsc: function() {
      if (this.get('model.viewOpen')) {
        this.shrink();
      }
    },

    openIfDraft: function() {
      if (this.get('model.viewDraft')) {
        this.set('model.composeState', Discourse.Composer.OPEN);
      }
    },

  },

  updateDraftStatus: function() {
    var c = this.get('model');
    if (c) { c.updateDraftStatus(); }
  },

  appendText: function(text) {
    var c = this.get('model');
    if (c) { c.appendText(text); }
  },

  appendBlockAtCursor: function(text) {
    var c = this.get('model');
    if (c) { c.appendText(text, $('#wmd-input').caret(), {block: true}); }
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

  disableSubmit: function() {
    return this.get('model.loading');
  }.property('model.loading'),

  save: function(force) {
    var composer = this.get('model'),
        self = this;

    if(composer.get('cantSubmitPost')) {
      var now = Date.now();
      this.setProperties({
        'view.showTitleTip': now,
        'view.showCategoryTip': now,
        'view.showReplyTip': now
      });
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
              self.save(true);
            }
          });
        }

        buttons.push({
          "label": I18n.t("composer.reply_original") + "<br/><div class='topic-title overflow-ellipsis'>" + this.get('model.topic.title') + "</div>",
          "class": "btn-primary btn-reply-on-original",
          "callback": function(){
            self.save(true);
          }
        });

        bootbox.dialog(message, buttons, {"classes": "reply-where-modal"});
        return;
      }
    }

    return composer.save({
      imageSizes: this.get('view').imageSizes(),
      editReason: this.get("editReason")
    }).then(function(opts) {

      // If we replied as a new topic successfully, remove the draft.
      if (self.get('replyAsNewTopicDraft')) {
        self.destroyDraft();
      }

      opts = opts || {};
      self.close();

      var currentUser = Discourse.User.current();
      if (composer.get('creatingTopic')) {
        currentUser.set('topic_count', currentUser.get('topic_count') + 1);
      } else {
        currentUser.set('reply_count', currentUser.get('reply_count') + 1);
      }

      if ((!composer.get('replyingToTopic')) || (!Discourse.User.currentProp('disable_jump_reply'))) {
        Discourse.URL.routeTo(opts.post.get('url'));
      }
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
      this.get('controllers.composer-messages').typedReply();
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

    var messageController = this.get('controllers.composer-messages'),
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

    if (!opts.draftKey) {
      alert("composer was opened without a draft key");
      throw "composer opened without a proper draft key";
    }

    var composerMessages = this.get('controllers.composer-messages'),
        self = this,
        composerModel = this.get('model');

    this.setProperties({ showEditReason: false, editReason: null });
    composerMessages.reset();

    // If we want a different draft than the current composer, close it and clear our model.
    if (composerModel && opts.draftKey !== composerModel.draftKey &&
        composerModel.composeState === Discourse.Composer.DRAFT) {
      this.close();
      composerModel = null;
    }

    return new Ember.RSVP.Promise(function(resolve, reject) {
      if (composerModel && composerModel.get('replyDirty')) {

        // If we're already open, we don't have to do anything
        if (composerModel.get('composeState') === Discourse.Composer.OPEN &&
            composerModel.get('draftKey') === opts.draftKey) {
          return resolve();
        }

        // If it's the same draft, just open it up again.
        if (composerModel.get('composeState') === Discourse.Composer.DRAFT &&
            composerModel.get('draftKey') === opts.draftKey &&
            composerModel.action === opts.action) {

            composerModel.set('composeState', Discourse.Composer.OPEN);
            return resolve();
        }

        // If it's a different draft, cancel it and try opening again.
        return self.cancelComposer().then(function() {
          return self.open(opts);
        }).then(resolve, reject);
      }

      // we need a draft sequence for the composer to work
      if (opts.draftSequence === void 0) {
        return Discourse.Draft.get(opts.draftKey).then(function(data) {
          opts.draftSequence = data.draft_sequence;
          opts.draft = data.draft;
          self._setModel(composerModel, opts);
        }).then(resolve, reject);
      }

      self._setModel(composerModel, opts);
      resolve();
    });
  },

  // Given a potential instance and options, set the model for this composer.
  _setModel: function(composerModel, opts) {
    if (opts.draft) {
      composerModel = Discourse.Composer.loadDraft(opts.draftKey, opts.draftSequence, opts.draft);
      if (composerModel) {
        composerModel.set('topic', opts.topic);
      }
    } else {
      composerModel = composerModel || Discourse.Composer.create();
      composerModel.open(opts);
    }

    this.set('model', composerModel);
    composerModel.set('composeState', Discourse.Composer.OPEN);

    var composerMessages = this.get('controllers.composer-messages');
    composerMessages.queryFor(composerModel);
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
    var self = this;

    return new Ember.RSVP.Promise(function (resolve) {
      if (self.get('model.hasMetaData') || self.get('model.replyDirty')) {
        bootbox.confirm(I18n.t("post.abandon.confirm"), I18n.t("post.abandon.no_value"),
            I18n.t("post.abandon.yes_value"), function(result) {
          if (result) {
            self.destroyDraft();
            self.get('model').clearState();
            self.close();
            resolve();
          }
        });
      } else {
        // it is possible there is some sort of crazy draft with no body ... just give up on it
        self.destroyDraft();
        self.get('model').clearState();
        self.close();
        resolve();
      }
    });
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
    this.setProperties({
      model: null,
      'view.showTitleTip': false,
      'view.showCategoryTip': false,
      'view.showReplyTip': false
    });
  },

  closeAutocomplete: function() {
    $('#wmd-input').autocomplete({ cancel: true });
  },

  showOptions: function() {
    var _ref;
    return (_ref = this.get('controllers.modal')) ? _ref.show(Discourse.ArchetypeOptionsModalView.create({
      archetype: this.get('model.archetype'),
      metaData: this.get('model.metaData')
    })) : void 0;
  },

  canEdit: function() {
    return this.get("model.action") === "edit" && Discourse.User.current().get("can_edit");
  }.property("model.action")

});
