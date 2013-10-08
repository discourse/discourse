/*global Markdown:true assetPath:true */

/**
  This view handles rendering of the composer

  @class ComposerView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ComposerView = Discourse.View.extend(Ember.Evented, {
  templateName: 'composer',
  elementId: 'reply-control',
  classNameBindings: ['model.creatingPrivateMessage:private-message',
                      'composeState',
                      'model.loading',
                      'model.canEditTitle:edit-title',
                      'postMade',
                      'model.creatingTopic:topic',
                      'model.showPreview',
                      'model.hidePreview'],

  model: Em.computed.alias('controller.model'),

  // This is just in case something still references content. Can probably be removed
  content: Em.computed.alias('model'),

  composeState: function() {
    var state = this.get('model.composeState');
    if (state) return state;
    return Discourse.Composer.CLOSED;
  }.property('model.composeState'),

  draftStatus: function() {
    $('#draft-status').text(this.get('model.draftStatus') || "");
  }.observes('model.draftStatus'),

  // Disable fields when we're loading
  loadingChanged: function() {
    if (this.get('loading')) {
      $('#wmd-input, #reply-title').prop('disabled', 'disabled');
    } else {
      $('#wmd-input, #reply-title').prop('disabled', '');
    }
  }.observes('loading'),

  postMade: function() {
    return this.present('controller.createdPost') ? 'created-post' : null;
  }.property('model.createdPost'),

  observeReplyChanges: function() {
    var self = this;
    if (this.get('model.hidePreview')) return;
    Ember.run.next(function() {
      if (self.editor) {
        self.editor.refreshPreview();
        // if the caret is on the last line ensure preview scrolled to bottom
        var caretPosition = Discourse.Utilities.caretPosition(self.wmdInput[0]);
        if (!self.wmdInput.val().substring(caretPosition).match(/\n/)) {
          var $wmdPreview = $('#wmd-preview');
          if ($wmdPreview.is(':visible')) {
            $wmdPreview.scrollTop($wmdPreview[0].scrollHeight);
          }
        }
      }
    });
  }.observes('model.reply', 'model.hidePreview'),

  movePanels: function(sizePx) {
    $('.composer-popup').css('bottom', sizePx);
  },

  focusIn: function() {
    var controller = this.get('controller');
    if (controller) controller.updateDraftStatus();
  },

  resize: function() {
    // this still needs to wait on animations, need a clean way to do that
    return Em.run.schedule('afterRender', function() {
      var replyControl = $('#reply-control');
      var h = replyControl.height() || 0;
      var sizePx = "" + h + "px";
      $('.topic-area').css('padding-bottom', sizePx);
      $('.composer-popup').css('bottom', sizePx);
    });
  }.observes('model.composeState'),

  keyUp: function(e) {
    var controller = this.get('controller');
    controller.checkReplyLength();

    var lastKeyUp = new Date();
    this.set('lastKeyUp', lastKeyUp);

    // One second from now, check to see if the last key was hit when
    // we recorded it. If it was, the user paused typing.
    var composerView = this;
    Em.run.later(function() {
      if (lastKeyUp !== composerView.get('lastKeyUp')) return;

      // Search for similar topics if the user pauses typing
      controller.findSimilarTopics();
    }, 1000);
  },

  keyDown: function(e) {
    // If the user hit ESC
    if (e.which === 27) {
      this.get('controller').hitEsc();
    }
  },

  didInsertElement: function() {
    var $replyControl = $('#reply-control');
    $replyControl.DivResizer({ resize: this.resize, onDrag: this.movePanels });
    Discourse.TransitionHelper.after($replyControl, this.resize);
    this.ensureMaximumDimensionForImagesInPreview();
  },

  ensureMaximumDimensionForImagesInPreview: function() {
    $('<style>#wmd-preview img, .cooked img {' +
      'max-width:' + Discourse.SiteSettings.max_image_width + 'px;' +
      'max-height:' + Discourse.SiteSettings.max_image_height + 'px;' +
      '}</style>'
     ).appendTo('head');
  },

  click: function() {
    this.get('controller').openIfDraft();
  },

  // Called after the preview renders. Debounced for performance
  afterRender: Discourse.debounce(function() {
    var $wmdPreview = $('#wmd-preview');
    if ($wmdPreview.length === 0) return;

    Discourse.SyntaxHighlighting.apply($wmdPreview);

    var post = this.get('model.post'),
        refresh = false;

    // If we are editing a post, we'll refresh its contents once. This is a feature that
    // allows a user to refresh its contents once.
    if (post && post.blank('refreshedPost')) {
      refresh = true;
      post.set('refreshedPost', true);
    }

    // Load the post processing effects
    $('a.onebox', $wmdPreview).each(function(i, e) {
      Discourse.Onebox.load(e, refresh);
    });
    $('span.mention', $wmdPreview).each(function(i, e) {
      Discourse.Mention.load(e, refresh);
    });

    this.trigger('previewRefreshed', $wmdPreview);
  }, 100),

  initEditor: function() {
    // not quite right, need a callback to pass in, meaning this gets called once,
    // but if you start replying to another topic it will get the avatars wrong
    var $wmdInput, editor, composerView = this;
    this.wmdInput = $wmdInput = $('#wmd-input');
    if ($wmdInput.length === 0 || $wmdInput.data('init') === true) return;

    $LAB.script(assetPath('defer/html-sanitizer-bundle'));
    Discourse.ComposerView.trigger("initWmdEditor");
    var template = Discourse.UserSelector.templateFunction();

    $wmdInput.data('init', true);
    $wmdInput.autocomplete({
      template: template,
      dataSource: function(term) {
        return Discourse.UserSearch.search({
          term: term,
          topicId: composerView.get('controller.controllers.topic.model.id')
        });
      },
      key: "@",
      transformComplete: function(v) { return v.username; }
    });

    this.editor = editor = Discourse.Markdown.createEditor({
      lookupAvatarByPostNumber: function(postNumber) {
        var posts = composerView.get('controller.controllers.topic.postStream.posts');
        if (posts) {
          var quotedPost = posts.findProperty("post_number", postNumber);
          if (quotedPost) {
            return Discourse.Utilities.tinyAvatar(quotedPost.get("avatar_template"));
          }
        }
      }
    });

    var $uploadTarget = $('#reply-control');
    this.editor.hooks.insertImageDialog = function(callback) {
      callback(null);
      composerView.get('controller').send('showUploadSelector', composerView);
      return true;
    };

    this.editor.hooks.onPreviewRefresh = function() {
      return composerView.afterRender();
    };

    this.editor.run();
    this.set('editor', this.editor);
    this.loadingChanged();

    var saveDraft = Discourse.debounce((function() {
      return composerView.get('controller').saveDraft();
    }), 2000);

    $wmdInput.keyup(function() {
      saveDraft();
      return true;
    });

    var $replyTitle = $('#reply-title');

    $replyTitle.keyup(function() {
      saveDraft();
      // removes the red background once the requirements are met
      if (composerView.get('model.missingTitleCharacters') <= 0) {
        $replyTitle.removeClass("requirements-not-met");
      }
      return true;
    });

    // when the title field loses the focus...
    $replyTitle.blur(function(){
      // ...and the requirements are not met (ie. the minimum number of characters)
      if (composerView.get('model.missingTitleCharacters') > 0) {
        // then, "redify" the background
        $replyTitle.toggleClass("requirements-not-met", true);
      }
    });

    // In case it's still bound somehow
    $uploadTarget.fileupload('destroy');
    $uploadTarget.off();

    $uploadTarget.fileupload({
        url: Discourse.getURL('/uploads'),
        dataType: 'json'
    });

    // submit - this event is triggered for each upload
    $uploadTarget.on('fileuploadsubmit', function (e, data) {
      var result = Discourse.Utilities.validateUploadedFiles(data.files);
      // reset upload status when everything is ok
      if (result) composerView.setProperties({ uploadProgress: 0, isUploading: true });
      return result;
    });

    // send - this event is triggered when the upload request is about to start
    $uploadTarget.on('fileuploadsend', function (e, data) {
      // hide the "file selector" modal
      composerView.get('controller').send('closeModal');
      // cf. https://github.com/blueimp/jQuery-File-Upload/wiki/API#how-to-cancel-an-upload
      var jqXHR = data.xhr();
      // need to wait for the link to show up in the DOM
      Em.run.schedule('afterRender', function() {
        // bind on the click event on the cancel link
        $('#cancel-file-upload').on('click', function() {
          // cancel the upload
          // NOTE: this will trigger a 'fileuploadfail' event with status = 0
          if (jqXHR) jqXHR.abort();
          // unbind
          $(this).off('click');
        });
      });
    });

    // progress all
    $uploadTarget.on('fileuploadprogressall', function (e, data) {
      var progress = parseInt(data.loaded / data.total * 100, 10);
      composerView.set('uploadProgress', progress);
    });

    // done
    $uploadTarget.on('fileuploaddone', function (e, data) {
      var markdown = Discourse.Utilities.getUploadMarkdown(data.result);
      // appends a space at the end of the inserted markdown
      composerView.addMarkdown(markdown + " ");
      composerView.set('isUploading', false);
    });

    // fail
    $uploadTarget.on('fileuploadfail', function (e, data) {
      // hide upload status
      composerView.set('isUploading', false);
      // display an error message
      Discourse.Utilities.displayErrorForUpload(data);
    });

    // I hate to use Em.run.later, but I don't think there's a way of waiting for a CSS transition
    // to finish.
    return Em.run.later(jQuery, (function() {
      var replyTitle = $('#reply-title');
      composerView.resize();
      return replyTitle.length ? replyTitle.putCursorAtEnd() : $wmdInput.putCursorAtEnd();
    }), 300);
  },

  addMarkdown: function(text) {
    var ctrl = $('#wmd-input').get(0),
        caretPosition = Discourse.Utilities.caretPosition(ctrl),
        current = this.get('model.reply');
    this.set('model.reply', current.substring(0, caretPosition) + text + current.substring(caretPosition, current.length));

    Em.run.schedule('afterRender', function() {
      Discourse.Utilities.setCaretPosition(ctrl, caretPosition + text.length);
    });
  },

  // Uses javascript to get the image sizes from the preview, if present
  imageSizes: function() {
    var result = {};
    $('#wmd-preview img').each(function(i, e) {
      var $img = $(e);
      result[$img.prop('src')] = {
        width: $img.width(),
        height: $img.height()
      };
    });
    return result;
  },

  childDidInsertElement: function(e) {
    return this.initEditor();
  },

  toggleAdminOptions: function() {
    var $adminOpts = $('.admin-options-form'),
        $wmd = $('.wmd-controls'),
        wmdTop = parseInt($wmd.css('top'),10);
    if( $adminOpts.is(':visible') ) {
      $wmd.css('top', wmdTop - parseInt($adminOpts.css('height'),10) + 'px' );
      $adminOpts.hide();
    } else {
      $adminOpts.show();
      $wmd.css('top', wmdTop + parseInt($adminOpts.css('height'),10) + 'px' );
    }
  },

  titleValidation: function() {
    var titleLength = this.get('model.titleLength'),
        missingChars = this.get('model.missingTitleCharacters'),
        reason;
    if( titleLength < 1 ){
      reason = I18n.t('composer.error.title_missing');
    } else if( missingChars > 0 ) {
      reason = I18n.t('composer.error.title_too_short', {min: this.get('model.minimumTitleLength')});
    } else if( titleLength > Discourse.SiteSettings.max_topic_title_length ) {
      reason = I18n.t('composer.error.title_too_long', {max: Discourse.SiteSettings.max_topic_title_length});
    }

    if( reason ) {
      return Discourse.InputValidation.create({ failed: true, reason: reason });
    }
  }.property('model.titleLength', 'model.missingTitleCharacters', 'model.minimumTitleLength'),

  categoryValidation: function() {
    if( !Discourse.SiteSettings.allow_uncategorized_topics && !this.get('model.categoryId')) {
      return Discourse.InputValidation.create({ failed: true, reason: I18n.t('composer.error.category_missing') });
    }
  }.property('model.categoryId'),

  replyValidation: function() {
    var replyLength = this.get('model.replyLength'),
        missingChars = this.get('model.missingReplyCharacters'),
        reason;
    if( replyLength < 1 ){
      reason = I18n.t('composer.error.post_missing');
    } else if( missingChars > 0 ) {
      reason = I18n.t('composer.error.post_length', {min: this.get('model.minimumPostLength')});
    }

    if( reason ) {
      return Discourse.InputValidation.create({ failed: true, reason: reason });
    }
  }.property('model.reply', 'model.replyLength', 'model.missingReplyCharacters', 'model.minimumPostLength')
});

// not sure if this is the right way, keeping here for now, we could use a mixin perhaps
Discourse.NotifyingTextArea = Ember.TextArea.extend({
  placeholder: function() {
    return I18n.t(this.get('placeholderKey'));
  }.property('placeholderKey'),

  didInsertElement: function() {
    return this.get('parent').childDidInsertElement(this);
  }
});

RSVP.EventTarget.mixin(Discourse.ComposerView);
