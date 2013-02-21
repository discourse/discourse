/*global Markdown:true assetPath:true */
(function() {

  window.Discourse.ComposerView = window.Discourse.View.extend({
    templateName: 'composer',
    elementId: 'reply-control',
    classNameBindings: ['content.creatingPrivateMessage:private-message', 
                        'composeState', 
                        'content.loading', 
                        'content.editTitle', 
                        'postMade', 
                        'content.creatingTopic:topic', 
                        'content.showPreview', 
                        'content.hidePreview'],
                        
    educationClosed: null,
    composeState: (function() {
      var state;
      state = this.get('content.composeState');
      if (!state) {
        state = Discourse.Composer.CLOSED;
      }
      return state;
    }).property('content.composeState'),
    draftStatus: (function() {
      return this.$('.saving-draft').text(this.get('content.draftStatus') || "");
    }).observes('content.draftStatus'),
    /* Disable fields when we're loading
    */

    loadingChanged: (function() {
      if (this.get('loading')) {
        return jQuery('#wmd-input, #reply-title').prop('disabled', 'disabled');
      } else {
        return jQuery('#wmd-input, #reply-title').prop('disabled', '');
      }
    }).observes('loading'),
    postMade: (function() {
      if (this.present('controller.createdPost')) {
        return 'created-post';
      }
      return null;
    }).property('content.createdPost'),
    observeReplyChanges: (function() {
      var _this = this;
      if (this.get('content.hidePreview')) {
        return;
      }
      return Ember.run.next(null, function() {
        var $wmdPreview, caretPosition;
        if (_this.editor) {
          _this.editor.refreshPreview();
          /* if the caret is on the last line ensure preview scrolled to bottom
          */

          caretPosition = Discourse.Utilities.caretPosition(_this.wmdInput[0]);
          if (!_this.wmdInput.val().substring(caretPosition).match(/\n/)) {
            $wmdPreview = jQuery('#wmd-preview:visible');
            if ($wmdPreview.length > 0) {
              return $wmdPreview.scrollTop($wmdPreview[0].scrollHeight);
            }
          }
        }
      });
    }).observes('content.reply', 'content.hidePreview'),
    closeEducation: function() {
      this.set('educationClosed', true);
      return false;
    },
    fetchNewUserEducation: (function() {
      /* If creating a topic, use topic_count, otherwise post_count
      */

      var count, educationKey,
        _this = this;
      count = this.get('content.creatingTopic') ? Discourse.get('currentUser.topic_count') : Discourse.get('currentUser.reply_count');
      if (count >= Discourse.SiteSettings.educate_until_posts) {
        this.set('educationClosed', true);
        this.set('educationContents', '');
        return;
      }
      if (!this.get('controller.hasReply')) {
        return;
      }
      this.set('educationClosed', false);
      /* If visible update the text
      */

      educationKey = this.get('content.creatingTopic') ? 'new-topic' : 'new-reply';
      return jQuery.get("/education/" + educationKey).then(function(result) {
        return _this.set('educationContents', result);
      });
    }).observes('controller.hasReply', 'content.creatingTopic', 'Discourse.currentUser.reply_count'),
    newUserEducationVisible: (function() {
      if (!this.get('educationContents')) {
        return false;
      }
      if (this.get('content.composeState') !== Discourse.Composer.OPEN) {
        return false;
      }
      if (!this.present('content.reply')) {
        return false;
      }
      if (this.get('educationClosed')) {
        return false;
      }
      return true;
    }).property('content.composeState', 'content.reply', 'educationClosed', 'educationContents'),
    newUserEducationVisibilityChanged: (function() {
      var $panel;
      $panel = jQuery('#new-user-education');
      if (this.get('newUserEducationVisible')) {
        return $panel.slideDown('fast');
      } else {
        return $panel.slideUp('fast');
      }
    }).observes('newUserEducationVisible'),
    moveNewUserEducation: function(sizePx) {
      return jQuery('#new-user-education').css('bottom', sizePx);
    },
    resize: (function() {
      /* this still needs to wait on animations, need a clean way to do that
      */

      var _this = this;
      return Em.run.next(null, function() {
        var h, replyControl, sizePx;
        replyControl = jQuery('#reply-control');
        h = replyControl.height() || 0;
        sizePx = "" + h + "px";
        jQuery('.topic-area').css('padding-bottom', sizePx);
        return jQuery('#new-user-education').css('bottom', sizePx);
      });
    }).observes('content.composeState'),
    keyUp: function(e) {
      var controller;
      controller = this.get('controller');
      controller.checkReplyLength();
      if (e.which === 27) {
        return controller.hitEsc();
      }
    },
    didInsertElement: function() {
      var replyControl;
      replyControl = jQuery('#reply-control');
      replyControl.DivResizer({
        resize: this.resize,
        onDrag: this.moveNewUserEducation
      });
      return Discourse.TransitionHelper.after(replyControl, this.resize);
    },
    click: function() {
      return this.get('controller').click();
    },
    /* Called after the preview renders. Debounced for performance
    */

    afterRender: Discourse.debounce(function() {
      var $wmdPreview, refresh,
        _this = this;
      $wmdPreview = jQuery('#wmd-preview');
      if ($wmdPreview.length === 0) {
        return;
      }
      Discourse.SyntaxHighlighting.apply($wmdPreview);
      refresh = this.get('controller.content.post.id') !== void 0;
      jQuery('a.onebox', $wmdPreview).each(function(i, e) {
        return Discourse.Onebox.load(e, refresh);
      });
      return jQuery('span.mention', $wmdPreview).each(function(i, e) {
        return Discourse.Mention.load(e, refresh);
      });
    }, 100),
    cancelUpload: function() {
      /* TODO
      */

    },
    initEditor: function() {
      /* not quite right, need a callback to pass in, meaning this gets called once,
      */

      /*    but if you start replying to another topic it will get the avatars wrong
      */

      var $uploadTarget, $wmdInput, editor, saveDraft, selected, template, topic, transformTemplate,
        _this = this;
      this.wmdInput = $wmdInput = jQuery('#wmd-input');
      if ($wmdInput.length === 0 || $wmdInput.data('init') === true) {
        return;
      }
      $LAB.script(assetPath('defer/html-sanitizer-bundle'));
      Discourse.ComposerView.trigger("initWmdEditor");
      template = Handlebars.compile("<div class='autocomplete'>" +
                                      "<ul>" +
                                      "{{#each options}}" +
                                        "<li>" +
                                            "<a href='#'>{{avatar this imageSize=\"tiny\"}} " +
                                            "<span class='username'>{{this.username}}</span> " +
                                            "<span class='name'>{{this.name}}</span></a>" +
                                        "</li>" +
                                        "{{/each}}" +
                                      "</ul>" +
                                    "</div>");
      transformTemplate = Handlebars.compile("{{avatar this imageSize=\"tiny\"}} {{this.username}}");
      $wmdInput.data('init', true);
      $wmdInput.autocomplete({
        template: template,
        dataSource: function(term, callback) {
          return Discourse.UserSearch.search({
            term: term,
            callback: callback,
            topicId: _this.get('controller.controllers.topic.content.id')
          });
        },
        key: "@",
        transformComplete: function(v) {
          return v.username;
        }
      });
      selected = [];
      jQuery('#private-message-users').val(this.get('content.targetUsernames')).autocomplete({
        template: template,
        dataSource: function(term, callback) {
          return Discourse.UserSearch.search({
            term: term,
            callback: callback,
            exclude: selected.concat([Discourse.get('currentUser.username')])
          });
        },
        onChangeItems: function(items) {
          items = jQuery.map(items, function(i) {
            if (i.username) {
              return i.username;
            } else {
              return i;
            }
          });
          _this.set('content.targetUsernames', items.join(","));
          selected = items;
        },
        transformComplete: transformTemplate,
        reverseTransform: function(i) {
          return {
            username: i
          };
        }
      });
      topic = this.get('topic');
      this.editor = editor = new Markdown.Editor(Discourse.Utilities.markdownConverter({
        lookupAvatar: function(username) {
          return Discourse.Utilities.avatarImg({
            username: username,
            size: 'tiny'
          });
        },
        sanitize: true
      }));
      $uploadTarget = jQuery('#reply-control');
      this.editor.hooks.insertImageDialog = function(callback) {
        callback(null);
        _this.get('controller.controllers.modal').show(Discourse.ImageSelectorView.create({
          composer: _this,
          uploadTarget: $uploadTarget
        }));
        return true;
      };
      this.editor.hooks.onPreviewRefresh = function() {
        return _this.afterRender();
      };
      this.editor.run();
      this.set('editor', this.editor);
      this.loadingChanged();
      saveDraft = Discourse.debounce((function() {
        return _this.get('controller').saveDraft();
      }), 2000);
      $wmdInput.keyup(function() {
        saveDraft();
        return true;
      });
      jQuery('#reply-title').keyup(function() {
        saveDraft();
        return true;
      });
      /* In case it's still bound somehow
      */

      $uploadTarget.fileupload('destroy');
      /* Add the upload action
      */

      $uploadTarget.fileupload({
        url: '/uploads',
        dataType: 'json',
        timeout: 20000,
        formData: {
          topic_id: 1234
        },
        paste: function(e, data) {
          if (data.files.length > 0) {
            _this.set('loadingImage', true);
            _this.set('uploadProgress', 0);
          }
          return true;
        },
        drop: function(e, data) {
          if (e.originalEvent.dataTransfer.files.length === 1) {
            _this.set('loadingImage', true);
            return _this.set('uploadProgress', 0);
          }
        },
        progressall: function(e, data) {
          var progress;
          progress = parseInt(data.loaded / data.total * 100, 10);
          return _this.set('uploadProgress', progress);
        },
        done: function(e, data) {
          var html, upload;
          _this.set('loadingImage', false);
          upload = data.result;
          html = "<img src=\"" + upload.url + "\" width=\"" + upload.width + "\" height=\"" + upload.height + "\">";
          return _this.addMarkdown(html);
        },
        fail: function(e, data) {
          bootbox.alert(Em.String.i18n('post.errors.upload'));
          return _this.set('loadingImage', false);
        }
      });

      // I hate to use Em.run.later, but I don't think there's a way of waiting for a CSS transition
      // to finish.
      return Em.run.later(jQuery, (function() {
        var replyTitle;
        replyTitle = jQuery('#reply-title');
        _this.resize();
        if (replyTitle.length) {
          return replyTitle.putCursorAtEnd();
        } else {
          return $wmdInput.putCursorAtEnd();
        }
      }), 300);
    },
    addMarkdown: function(text) {
      var caretPosition, ctrl, current,
        _this = this;
      ctrl = jQuery('#wmd-input').get(0);
      caretPosition = Discourse.Utilities.caretPosition(ctrl);
      current = this.get('content.reply');
      this.set('content.reply', current.substring(0, caretPosition) + text + current.substring(caretPosition, current.length));
      return Em.run.next(function() {
        return Discourse.Utilities.setCaretPosition(ctrl, caretPosition + text.length);
      });
    },
    /* Uses javascript to get the image sizes from the preview, if present
    */

    imageSizes: function() {
      var result;
      result = {};
      jQuery('#wmd-preview img').each(function(i, e) {
        var $img;
        $img = jQuery(e);
        result[$img.prop('src')] = {
          width: $img.width(),
          height: $img.height()
        };
      });
      return result;
    },
    childDidInsertElement: function(e) {
      return this.initEditor();
    }
  });

  // not sure if this is the right way, keeping here for now, we could use a mixin perhaps
  Discourse.NotifyingTextArea = Ember.TextArea.extend({
    placeholder: (function() {
      return Em.String.i18n(this.get('placeholderKey'));
    }).property('placeholderKey'),
    didInsertElement: function() {
      return this.get('parent').childDidInsertElement(this);
    }
  });

  RSVP.EventTarget.mixin(Discourse.ComposerView);

}).call(this);
