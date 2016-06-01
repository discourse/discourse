import DiscourseURL from 'discourse/lib/url';
import Quote from 'discourse/lib/quote';
import Draft from 'discourse/models/draft';
import Composer from 'discourse/models/composer';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

function loadDraft(store, opts) {
  opts = opts || {};

  let draft = opts.draft;
  const draftKey = opts.draftKey;
  const draftSequence = opts.draftSequence;

  try {
    if (draft && typeof draft === 'string') {
      draft = JSON.parse(draft);
    }
  } catch (error) {
    draft = null;
    Draft.clear(draftKey, draftSequence);
  }
  if (draft && ((draft.title && draft.title !== '') || (draft.reply && draft.reply !== ''))) {
    const composer = store.createRecord('composer');
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
      typingTime: draft.typingTime
    });
    return composer;
  }
}

export default Ember.Controller.extend({
  needs: ['modal', 'topic', 'composer-messages', 'application'],

  replyAsNewTopicDraft: Em.computed.equal('model.draftKey', Composer.REPLY_AS_NEW_TOPIC_KEY),
  checkedMessages: false,

  showEditReason: false,
  editReason: null,
  scopedCategoryId: null,
  similarTopics: null,
  similarTopicsMessage: null,
  lastSimilaritySearch: null,
  optionsVisible: false,
  lastValidatedAt: null,
  isUploading: false,
  topic: null,
  showToolbar: Em.computed({
    get(){
      const keyValueStore = this.container.lookup('key-value-store:main');
      const storedVal = keyValueStore.get("toolbar-enabled");
      if (this._toolbarEnabled === undefined && storedVal === undefined) {
        // iPhone 6 is 375, anything narrower and toolbar should
        // be default disabled.
        // That said we should remember the state
        this._toolbarEnabled = $(window).width() > 370;
      }
      return this._toolbarEnabled || storedVal === "true";
    },
    set(key, val){
      const keyValueStore = this.container.lookup('key-value-store:main');
      this._toolbarEnabled = val;
      keyValueStore.set({key: "toolbar-enabled", value: val ? "true" : "false"});
      return val;
    }
  }),

  topicModel: Ember.computed.alias('controllers.topic.model'),

  _initializeSimilar: function() {
    this.set('similarTopics', []);
  }.on('init'),

  @computed('model.canEditTitle', 'model.creatingPrivateMessage')
  canEditTags(canEditTitle, creatingPrivateMessage) {
    return !this.site.mobileView &&
            this.site.get('can_tag_topics') &&
            canEditTitle &&
            !creatingPrivateMessage;
  },

  @computed('model.action')
  canWhisper(action) {
    const currentUser = this.currentUser;
    return currentUser && currentUser.get('staff') && this.siteSettings.enable_whispers && action === Composer.REPLY;
  },

  showWarning: function() {
    if (!Discourse.User.currentProp('staff')) { return false; }

    var usernames = this.get('model.targetUsernames');
    var hasTargetGroups = this.get('model.hasTargetGroups');

    // We need exactly one user to issue a warning
    if (Ember.isEmpty(usernames) || usernames.split(',').length !== 1 || hasTargetGroups) {
      return false;
    }
    return this.get('model.creatingPrivateMessage');
  }.property('model.creatingPrivateMessage', 'model.targetUsernames'),

  actions: {

    toggleWhisper() {
      this.toggleProperty('model.whisper');
    },

    toggleToolbar() {
      this.toggleProperty('showToolbar');
    },

    showOptions(loc) {
      this.appEvents.trigger('popup-menu:open', loc);
      this.set('optionsVisible', true);
    },

    hideOptions() {
      this.set('optionsVisible', false);
    },

    // Toggle the reply view
    toggle() {
      this.toggle();
    },

    togglePreview() {
      this.get('model').togglePreview();
    },

    // Import a quote from the post
    importQuote(toolbarEvent) {
      const postStream = this.get('topic.postStream');
      let postId = this.get('model.post.id');

      // If there is no current post, use the first post id from the stream
      if (!postId && postStream) {
        postId = postStream.get('stream.firstObject');
      }

      // If we're editing a post, fetch the reply when importing a quote
      if (this.get('model.editingPost')) {
        const replyToPostNumber = this.get('model.post.reply_to_post_number');
        if (replyToPostNumber) {
          const replyPost = postStream.get('posts').findBy('post_number', replyToPostNumber);
          if (replyPost) {
            postId = replyPost.get('id');
          }
        }
      }

      if (postId) {
        this.set('model.loading', true);
        const composer = this;

        return this.store.find('post', postId).then(function(post) {
          const quote = Quote.build(post, post.get("raw"), {raw: true, full: true});
          toolbarEvent.addText(quote);
          composer.set('model.loading', false);
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
      const messages = this.get('controllers.composer-messages.model');
      if (messages.length) {
        messages.popObject();
        return;
      }

      if (this.get('model.viewOpen')) {
        this.shrink();
      }
    },

    openIfDraft() {
      if (this.get('model.viewDraft')) {
        this.set('model.composeState', Composer.OPEN);
      }
    },

    groupsMentioned(groups) {
      if (!this.get('model.creatingPrivateMessage') && !this.get('model.topic.isPrivateMessage')) {
        this.get('controllers.composer-messages').groupsMentioned(groups);
      }
    }

  },

  categories: function() {
    return Discourse.Category.list();
  }.property(),

  toggle() {
    this.closeAutocomplete();
    switch (this.get('model.composeState')) {
      case Composer.OPEN:
        if (Ember.isEmpty(this.get('model.reply')) && Ember.isEmpty(this.get('model.title'))) {
          this.close();
        } else {
          this.shrink();
        }
        break;
      case Composer.DRAFT:
        this.set('model.composeState', Composer.OPEN);
        break;
      case Composer.SAVING:
        this.close();
    }
    return false;
  },

  disableSubmit: Ember.computed.or("model.loading", "isUploading"),

  save(force) {
    const composer = this.get('model');
    const self = this;

    // Clear the warning state if we're not showing the checkbox anymore
    if (!this.get('showWarning')) {
      this.set('model.isWarning', false);
    }

    if (composer.get('cantSubmitPost')) {
      this.set('lastValidatedAt', Date.now());
      return;
    }

    composer.set('disableDrafts', true);

    // for now handle a very narrow use case
    // if we are replying to a topic AND not on the topic pop the window up
    if (!force && composer.get('replyingToTopic')) {

      const currentTopic = this.get('topicModel');
      if (!currentTopic || currentTopic.get('id') !== composer.get('topic.id'))
      {
        const message = I18n.t("composer.posting_not_on_topic");

        let buttons = [{
          "label": I18n.t("composer.cancel"),
          "class": "cancel",
          "link": true
        }];

        if (currentTopic) {
          buttons.push({
            "label": I18n.t("composer.reply_here") + "<br/><div class='topic-title overflow-ellipsis'>" + Discourse.Utilities.escapeExpression(currentTopic.get('title')) + "</div>",
            "class": "btn btn-reply-here",
            "callback": function() {
              composer.set('topic', currentTopic);
              composer.set('post', null);
              self.save(true);
            }
          });
        }

        buttons.push({
          "label": I18n.t("composer.reply_original") + "<br/><div class='topic-title overflow-ellipsis'>" + Discourse.Utilities.escapeExpression(this.get('model.topic.title')) + "</div>",
          "class": "btn-primary btn-reply-on-original",
          "callback": function() {
            self.save(true);
          }
        });

        bootbox.dialog(message, buttons, { "classes": "reply-where-modal" });
        return;
      }
    }

    var staged = false;

    // TODO: This should not happen in model
    const imageSizes = {};
    $('#reply-control .d-editor-preview img').each((i, e) => {
      const $img = $(e);
      const src = $img.prop('src');

      if (src && src.length) {
        imageSizes[src] = { width: $img.width(), height: $img.height() };
      }
    });

    const promise = composer.save({ imageSizes, editReason: this.get("editReason")}).then(function(result) {
      if (result.responseJson.action === "enqueued") {
        self.send('postWasEnqueued', result.responseJson);
        self.destroyDraft();
        self.close();
        self.appEvents.trigger('post-stream:refresh');
        return result;
      }

      // If user "created a new topic/post" or "replied as a new topic" successfully, remove the draft.
      if (result.responseJson.action === "create_post" || self.get('replyAsNewTopicDraft')) {
        self.destroyDraft();
      }
      if (self.get('model.action') === 'edit') {
        self.appEvents.trigger('post-stream:refresh', { id: parseInt(result.responseJson.id) });
      } else {
        self.appEvents.trigger('post-stream:refresh');
      }

      if (result.responseJson.action === "create_post") {
        self.appEvents.trigger('post:highlight', result.payload.post_number);
      }
      self.close();

      const currentUser = Discourse.User.current();
      if (composer.get('creatingTopic')) {
        currentUser.set('topic_count', currentUser.get('topic_count') + 1);
      } else {
        currentUser.set('reply_count', currentUser.get('reply_count') + 1);
      }

      const disableJumpReply = Discourse.User.currentProp('disable_jump_reply');
      if (!composer.get('replyingToTopic') || !disableJumpReply) {
        const post = result.target;
        if (post && !staged) {
          DiscourseURL.routeTo(post.get('url'));
        }
      }

    }).catch(function(error) {
      composer.set('disableDrafts', false);
      self.appEvents.one('composer:will-open', () => bootbox.alert(error));
    });

    if (this.get('controllers.application.currentRouteName').split('.')[0] === 'topic' &&
        composer.get('topic.id') === this.get('topicModel.id')) {
      staged = composer.get('stagedPost');
    }

    this.appEvents.trigger('post-stream:posted', staged);

    this.messageBus.pause();
    promise.finally(() => this.messageBus.resume());

    return promise;
  },

  // Checks to see if a reply has been typed.
  // This is signaled by a keyUp event in a view.
  checkReplyLength() {
    if (!Ember.isEmpty('model.reply')) {
      // Notify the composer messages controller that a reply has been typed. Some
      // messages only appear after typing.
      this.get('controllers.composer-messages').typedReply();
    }
  },

  // Fired after a user stops typing.
  // Considers whether to check for similar topics based on the current composer state.
  findSimilarTopics() {
    // We don't care about similar topics unless creating a topic
    if (!this.get('model.creatingTopic')) { return; }

    let body = this.get('model.reply') || '';
    const title = this.get('model.title') || '';

    // Ensure the fields are of the minimum length
    if (body.length < Discourse.SiteSettings.min_body_similar_length) { return; }
    if (title.length < Discourse.SiteSettings.min_title_similar_length) { return; }

    // TODO pass the 200 in from somewhere
    body = body.substr(0, 200);

    // Done search over and over
    if ((title + body) === this.get('lastSimilaritySearch')) { return; }
    this.set('lastSimilaritySearch', title + body);

    const messageController = this.get('controllers.composer-messages'),
          similarTopics = this.get('similarTopics');

    let message = this.get('similarTopicsMessage');
    if (!message) {
      message = Discourse.ComposerMessage.create({
        templateName: 'composer/similar-topics',
        extraClass: 'similar-topics'
      });
      this.set('similarTopicsMessage', message);
    }

    this.store.find('similar-topic', {title, raw: body}).then(function(newTopics) {
      similarTopics.clear();
      similarTopics.pushObjects(newTopics.get('content'));

      if (similarTopics.get('length') > 0) {
        message.set('similarTopics', similarTopics);
        messageController.send("popup", message);
      } else if (message) {
        messageController.send("hideMessage", message);
      }
    });
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
      alert("composer was opened without a draft key");
      throw "composer opened without a proper draft key";
    }

    // If we show the subcategory list, scope the categories drop down to
    // the category we opened the composer with.
    if (this.siteSettings.show_subcategory_list && opts.draftKey !== 'reply_as_new_topic') {
      this.set('scopedCategoryId', opts.categoryId);
    }

    const composerMessages = this.get('controllers.composer-messages'),
          self = this;

    let composerModel = this.get('model');

    this.setProperties({ showEditReason: false, editReason: null });
    composerMessages.reset();

    // If we want a different draft than the current composer, close it and clear our model.
    if (composerModel &&
        opts.draftKey !== composerModel.draftKey &&
        composerModel.composeState === Composer.DRAFT) {
      this.close();
      composerModel = null;
    }

    return new Ember.RSVP.Promise(function(resolve, reject) {
      if (composerModel && composerModel.get('replyDirty')) {

        // If we're already open, we don't have to do anything
        if (composerModel.get('composeState') === Composer.OPEN &&
            composerModel.get('draftKey') === opts.draftKey && !opts.action) {
          return resolve();
        }

        // If it's the same draft, just open it up again.
        if (composerModel.get('composeState') === Composer.DRAFT &&
            composerModel.get('draftKey') === opts.draftKey) {
          composerModel.set('composeState', Composer.OPEN);
          if (!opts.action) return resolve();
        }

        // If it's a different draft, cancel it and try opening again.
        return self.cancelComposer().then(function() {
          return self.open(opts);
        }).then(resolve, reject);
      }

      // we need a draft sequence for the composer to work
      if (opts.draftSequence === undefined) {
        return Draft.get(opts.draftKey).then(function(data) {
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
  _setModel(composerModel, opts) {
    if (opts.draft) {
      composerModel = loadDraft(this.store, opts);
      if (composerModel) {
        composerModel.set('topic', opts.topic);
      }
    } else {
      composerModel = composerModel || this.store.createRecord('composer');
      composerModel.open(opts);
    }

    this.set('model', composerModel);
    composerModel.set('composeState', Composer.OPEN);
    composerModel.set('isWarning', false);

    if (opts.topicTitle && opts.topicTitle.length <= this.siteSettings.max_topic_title_length) {
      this.set('model.title', opts.topicTitle);
    }

    if (opts.topicCategoryId) {
      this.set('model.categoryId', opts.topicCategoryId);
    } else if (opts.topicCategory) {
      const splitCategory = opts.topicCategory.split("/");
      let category;

      if (!splitCategory[1]) {
        category = this.site.get('categories').findProperty('nameLower', splitCategory[0].toLowerCase());
      } else {
        const categories = Discourse.Category.list();
        const mainCategory = categories.findProperty('nameLower', splitCategory[0].toLowerCase());
        category = categories.find(function(item) {
          return item && item.get('nameLower') === splitCategory[1].toLowerCase() && item.get('parent_category_id') === mainCategory.id;
        });
      }

      if (category) {
        this.set('model.categoryId', category.get('id'));
      }
    }

    if (opts.topicBody) {
      this.set('model.reply', opts.topicBody);
    }

    this.get('controllers.composer-messages').queryFor(composerModel);
  },

  // View a new reply we've made
  viewNewReply() {
    DiscourseURL.routeTo(this.get('model.createdPost.url'));
    this.close();
    return false;
  },

  destroyDraft() {
    const key = this.get('model.draftKey');
    if (key) {
      Draft.clear(key, this.get('model.draftSequence'));
    }
  },

  cancelComposer() {
    const self = this;

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

  shrink() {
    if (this.get('model.replyDirty')) {
      this.collapse();
    } else {
      this.close();
    }
  },

  _saveDraft() {
    const model = this.get('model');
    if (model) { model.saveDraft(); };
  },

  @observes('model.reply', 'model.title')
  _shouldSaveDraft() {
    Ember.run.debounce(this, this._saveDraft, 2000);
  },

  @computed('model.categoryId', 'lastValidatedAt')
  categoryValidation(categoryId, lastValidatedAt) {
    if( !this.siteSettings.allow_uncategorized_topics && !categoryId) {
      return Discourse.InputValidation.create({ failed: true, reason: I18n.t('composer.error.category_missing'), lastShownAt: lastValidatedAt });
    }
  },

  collapse() {
    this._saveDraft();
    this.set('model.composeState', Composer.DRAFT);
  },

  close() {
    this.setProperties({ model: null, lastValidatedAt: null });
  },

  closeAutocomplete() {
    $('.d-editor-input').autocomplete({ cancel: true });
  },

  canEdit: function() {
    return this.get("model.action") === "edit" && Discourse.User.current().get("can_edit");
  }.property("model.action"),

  visible: function() {
    var state = this.get('model.composeState');
    return state && state !== 'closed';
  }.property('model.composeState')

});
