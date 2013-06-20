/*global Markdown:true assetPath:true */

/**
  This view handles rendering of the composer

  @class ComposerView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ComposerView = Discourse.View.extend({
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

  composeState: function() {
    var state = this.get('content.composeState');
    if (state) return state;
    return Discourse.Composer.CLOSED;
  }.property('content.composeState'),

  draftStatus: function() {
    $('#draft-status').text(this.get('content.draftStatus') || "");
  }.observes('content.draftStatus'),

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
  }.property('content.createdPost'),

  observeReplyChanges: function() {
    var composerView = this;
    if (this.get('content.hidePreview')) return;
    Ember.run.next(null, function() {
      var $wmdPreview, caretPosition;
      if (composerView.editor) {
        composerView.editor.refreshPreview();
        // if the caret is on the last line ensure preview scrolled to bottom
        caretPosition = Discourse.Utilities.caretPosition(composerView.wmdInput[0]);
        if (!composerView.wmdInput.val().substring(caretPosition).match(/\n/)) {
          $wmdPreview = $('#wmd-preview');
          if ($wmdPreview.is(':visible')) {
            return $wmdPreview.scrollTop($wmdPreview[0].scrollHeight);
          }
        }
      }
    });
  }.observes('content.reply', 'content.hidePreview'),

  newUserEducationVisibilityChanged: function() {
    var $panel = $('#new-user-education');
    if (this.get('controller.newUserEducationVisible')) {
      $panel.slideDown('fast');
    } else {
      $panel.slideUp('fast');
    }
  }.observes('controller.newUserEducationVisible'),

  similarVisibilityChanged: function() {
    var $panel = $('#similar-topics');
    if (this.get('controller.similarVisible')) {
      $panel.slideDown('fast');
    } else {
      $panel.slideUp('fast');
    }
  }.observes('controller.similarVisible'),

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
  }.observes('content.composeState'),

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
  },

  click: function() {
    this.get('controller').openIfDraft();
  },

  // Called after the preview renders. Debounced for performance
  afterRender: Discourse.debounce(function() {
    var $wmdPreview = $('#wmd-preview');
    if ($wmdPreview.length === 0) return;

    Discourse.SyntaxHighlighting.apply($wmdPreview);

    var post = this.get('controller.content.post');
    var refresh = false;

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
          topicId: composerView.get('controller.controllers.topic.content.id')
        });
      },
      key: "@",
      transformComplete: function(v) { return v.username; }
    });

    this.editor = editor = Discourse.Markdown.createEditor({
      lookupAvatar: function(username) {
        return Discourse.Utilities.avatarImg({ username: username, size: 'tiny' });
      }
    });

    var $uploadTarget = $('#reply-control');
    this.editor.hooks.insertImageDialog = function(callback) {
      callback(null);
      composerView.get('controller').send('showImageSelector', composerView);
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
      if (composerView.get('controller.content.missingTitleCharacters') <= 0) {
        $replyTitle.removeClass("requirements-not-met");
      }
      return true;
    });

    // when the title field loses the focus...
    $replyTitle.blur(function(){
      // ...and the requirements are not met (ie. the minimum number of characters)
      if (composerView.get('controller.content.missingTitleCharacters') > 0) {
        // then, "redify" the background
        $replyTitle.toggleClass("requirements-not-met", true);
      }
    });

    // In case it's still bound somehow
    $uploadTarget.fileupload('destroy');
    $uploadTarget.off();

    $uploadTarget.fileupload({
        url: Discourse.getURL('/uploads'),
        dataType: 'json',
        timeout: 20000
    });

    // submit - this event is triggered for each upload
    $uploadTarget.on('fileuploadsubmit', function (e, data) {
      var result = Discourse.Utilities.validateFilesForUpload(data.files);
      // reset upload status when everything is ok
      if (result) composerView.setProperties({ uploadProgress: 0, loadingImage: true });
      return result;
    });

    // send - this event is triggered when the upload request is about to start
    $uploadTarget.on('fileuploadsend', function (e, data) {
      // hide the "image selector" modal
      composerView.get('controller').send('closeModal');
      // cf. https://github.com/blueimp/jQuery-File-Upload/wiki/API#how-to-cancel-an-upload
      var jqXHR = data.xhr();
      // need to wait for the link to show up in the DOM
      Em.run.schedule('afterRender', function() {
        // bind on the click event on the cancel link
        $('#cancel-image-upload').on('click', function() {
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
      var upload = data.result;
      var html = "<img src=\"" + upload.url + "\" width=\"" + upload.width + "\" height=\"" + upload.height + "\">";
      composerView.addMarkdown(html);
      composerView.set('loadingImage', false);
    });

    // fail
    $uploadTarget.on('fileuploadfail', function (e, data) {
      // hide upload status
      composerView.set('loadingImage', false);
      // deal with meaningful errors first
      if (data.jqXHR) {
        switch (data.jqXHR.status) {
          // 0 == cancel from the user
          case 0: return;
          // 413 == entity too large, returned usually from nginx
          case 413:
            bootbox.alert(Em.String.i18n('post.errors.upload_too_large', {max_size_kb: Discourse.SiteSettings.max_upload_size_kb}));
            return;
          // 415 == media type not recognized (ie. not an image)
          case 415:
            bootbox.alert(Em.String.i18n('post.errors.only_images_are_supported'));
            return;
          // 422 == there has been an error on the server (mostly due to FastImage)
          case 422:
            bootbox.alert(data.jqXHR.responseText);
            return;
        }
      }
      // otherwise, display a generic error message
      bootbox.alert(Em.String.i18n('post.errors.upload'));
    });

    // I hate to use Em.run.later, but I don't think there's a way of waiting for a CSS transition
    // to finish.
    return Em.run.later(jQuery, (function() {
      var replyTitle = $('#reply-title');
      composerView.resize();
      if (replyTitle.length) {
        return replyTitle.putCursorAtEnd();
      } else {
        return $wmdInput.putCursorAtEnd();
      }
    }), 300);
  },

  addMarkdown: function(text) {
    var ctrl = $('#wmd-input').get(0),
        caretPosition = Discourse.Utilities.caretPosition(ctrl),
        current = this.get('content.reply');
    this.set('content.reply', current.substring(0, caretPosition) + text + current.substring(caretPosition, current.length));

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
    var titleLength = this.get('content.titleLength'),
        missingChars = this.get('content.missingTitleCharacters'),
        reason;
    if( titleLength < 1 ){
      reason = Em.String.i18n('composer.error.title_missing');
    } else if( missingChars > 0 ) {
      reason = Em.String.i18n('composer.error.title_too_short', {min: this.get('content.minimumTitleLength')});
    } else if( titleLength > Discourse.SiteSettings.max_topic_title_length ) {
      reason = Em.String.i18n('composer.error.title_too_long', {max: Discourse.SiteSettings.max_topic_title_length});
    }

    if( reason ) {
      return Discourse.InputValidation.create({ failed: true, reason: reason });
    }
  }.property('content.titleLength', 'content.missingTitleCharacters', 'content.minimumTitleLength'),

  categoryValidation: function() {
    if( !Discourse.SiteSettings.allow_uncategorized_topics && !this.get('content.categoryName')) {
      return Discourse.InputValidation.create({ failed: true, reason: Em.String.i18n('composer.error.category_missing') });
    }
  }.property('content.categoryName'),

  replyValidation: function() {
    var replyLength = this.get('content.replyLength'),
        missingChars = this.get('content.missingReplyCharacters'),
        reason;
    if( replyLength < 1 ){
      reason = Em.String.i18n('composer.error.post_missing');
    } else if( missingChars > 0 ) {
      reason = Em.String.i18n('composer.error.post_length', {min: this.get('content.minimumPostLength')});
    }

    if( reason ) {
      return Discourse.InputValidation.create({ failed: true, reason: reason });
    }
  }.property('content.reply', 'content.replyLength', 'content.missingReplyCharacters', 'content.minimumPostLength')
});

// not sure if this is the right way, keeping here for now, we could use a mixin perhaps
Discourse.NotifyingTextArea = Ember.TextArea.extend({
  placeholder: function() {
    return Em.String.i18n(this.get('placeholderKey'));
  }.property('placeholderKey'),

  didInsertElement: function() {
    return this.get('parent').childDidInsertElement(this);
  }
});

RSVP.EventTarget.mixin(Discourse.ComposerView);
