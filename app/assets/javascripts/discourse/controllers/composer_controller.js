(function() {

  window.Discourse.ComposerController = Ember.Controller.extend(Discourse.Presence, {
    needs: ['modal', 'topic'],
    hasReply: false,
    togglePreview: function() {
      return this.get('content').togglePreview();
    },
    /* Import a quote from the post
    */

    importQuote: function() {
      return this.get('content').importQuote();
    },
    appendText: function(text) {
      var c;
      c = this.get('content');
      if (c) {
        return c.appendText(text);
      }
    },
    save: function() {
      var composer,
        _this = this;
      composer = this.get('content');
      composer.set('disableDrafts', true);
      return composer.save({
        imageSizes: this.get('view').imageSizes()
      }).then(function(opts) {
        opts = opts || {};
        _this.close();
        if (composer.get('creatingTopic')) {
          Discourse.set('currentUser.topic_count', Discourse.get('currentUser.topic_count') + 1);
        } else {
          Discourse.set('currentUser.reply_count', Discourse.get('currentUser.reply_count') + 1);
        }
        return Discourse.routeTo(opts.post.get('url'));
      }, function(error) {
        composer.set('disableDrafts', false);
        return bootbox.alert(error);
      });
    },
    checkReplyLength: function() {
      if (this.present('content.reply')) {
        return this.set('hasReply', true);
      } else {
        return this.set('hasReply', false);
      }
    },
    saveDraft: function() {
      var model;
      model = this.get('content');
      if (model) {
        return model.saveDraft();
      }
    },
    /* 
      Open the reply view

      opts:
      action   - The action we're performing: edit, reply or createTopic
      post     - The post we're replying to, if present
      topic    - The topic we're replying to, if present
      quote    - If we're opening a reply from a quote, the quote we're making
    */

    open: function(opts) {
      var composer, promise, view,
        _this = this;
      if (!opts) opts = {};

      opts.promise = promise = opts.promise || new RSVP.Promise();
      this.set('hasReply', false);
      if (!opts.draftKey) {
        alert("composer was opened without a draft key");
        throw "composer opened without a proper draft key";
      }
      /* ensure we have a view now, without it transitions are going to be messed
      */

      view = this.get('view');
      if (!view) {
        view = Discourse.ComposerView.create({
          controller: this
        });
        view.appendTo(jQuery('#main'));
        this.set('view', view);
        /* the next runloop is too soon, need to get the control rendered and then
        */

        /*  we need to change stuff, otherwise css animations don't kick in
        */

        Em.run.next(function() {
          return Em.run.next(function() {
            return _this.open(opts);
          });
        });
        return promise;
      }
      composer = this.get('content');
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
            this.cancel((function() {
              return _this.open(opts);
            }), (function() {
              return promise.reject();
            }));
          }
          return promise;
        }
      }
      /* we need a draft sequence, without it drafts are bust
      */

      if (opts.draftSequence === void 0) {
        Discourse.Draft.get(opts.draftKey).then(function(data) {
          opts.draftSequence = data.draft_sequence;
          opts.draft = data.draft;
          return _this.open(opts);
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
      var composer;
      composer = this.get('content');
      return composer && composer.wouldLoseChanges();
    },
    /* View a new reply we've made
    */

    viewNewReply: function() {
      Discourse.routeTo(this.get('createdPost.url'));
      this.close();
      return false;
    },
    destroyDraft: function() {
      var key;
      key = this.get('content.draftKey');
      if (key) {
        return Discourse.Draft.clear(key, this.get('content.draftSequence'));
      }
    },
    cancel: function(success, fail) {
      var _this = this;
      if (this.get('content.hasMetaData') || ((this.get('content.reply') || "") !== (this.get('content.originalText') || ""))) {
        bootbox.confirm(Em.String.i18n("post.abandon"), Em.String.i18n("no_value"), Em.String.i18n("yes_value"), function(result) {
          if (result) {
            _this.destroyDraft();
            _this.close();
            if (typeof success === "function") {
              return success();
            }
          } else {
            if (typeof fail === "function") {
              return fail();
            }
          }
        });
      } else {
        /* it is possible there is some sort of crazy draft with no body ... just give up on it
        */

        this.destroyDraft();
        this.close();
        if (typeof success === "function") {
          success();
        }
      }
    },
    click: function() {
      if (this.get('content.composeState') === Discourse.Composer.DRAFT) {
        return this.set('content.composeState', Discourse.Composer.OPEN);
      }
    },
    shrink: function() {
      if (this.get('content.reply') === this.get('content.originalText')) {
        return this.close();
      } else {
        return this.collapse();
      }
    },
    collapse: function() {
      this.saveDraft();
      return this.set('content.composeState', Discourse.Composer.DRAFT);
    },
    close: function() {
      this.set('content', null);
      return this.set('view.content', null);
    },
    closeIfCollapsed: function() {
      if (this.get('content.composeState') === Discourse.Composer.DRAFT) {
        return this.close();
      }
    },
    closeAutocomplete: function() {
      return jQuery('#wmd-input').autocomplete({
        cancel: true
      });
    },
    /* Toggle the reply view
    */

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
    /* ESC key hit
    */

    hitEsc: function() {
      if (this.get('content.composeState') === Discourse.Composer.OPEN) {
        return this.shrink();
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

}).call(this);
