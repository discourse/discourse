/*global assetPath:true */

/**
  This view handles rendering of the composer

  @class ComposerView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
var ComposerView = Discourse.View.extend(Ember.Evented, {
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
    return this.get('model.composeState') || Discourse.Composer.CLOSED;
  }.property('model.composeState'),

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

  refreshPreview: Discourse.debounce(function() {
    if (this.editor) {
      this.editor.refreshPreview();
    }
  }, 30),

  observeReplyChanges: function() {
    if (this.get('model.hidePreview')) return;
    Ember.run.scheduleOnce('afterRender', this, 'refreshPreview');
  }.observes('model.reply', 'model.hidePreview'),

  focusIn: function() {
    var controller = this.get('controller');
    if (controller) controller.updateDraftStatus();
  },

  movePanels: function(sizePx) {
    $('#main-outlet').css('padding-bottom', sizePx);
    $('.composer-popup').css('bottom', sizePx);
    // signal the progress bar it should move!
    this.appEvents.trigger("composer:resized");
  },

  resize: function() {
    var self = this;
    Em.run.scheduleOnce('afterRender', function() {
      if (self.movePanels) {
        var h = $('#reply-control').height() || 0;
        self.movePanels.apply(self, [h + "px"]);
      }
    });
  }.observes('model.composeState'),

  keyUp: function() {
    var controller = this.get('controller');
    controller.checkReplyLength();

    var lastKeyUp = new Date();
    this.set('lastKeyUp', lastKeyUp);

    // One second from now, check to see if the last key was hit when
    // we recorded it. If it was, the user paused typing.
    var self = this;
    Em.run.later(function() {
      if (lastKeyUp !== self.get('lastKeyUp')) return;

      // Search for similar topics if the user pauses typing
      controller.findSimilarTopics();
    }, 1000);
  },

  keyDown: function(e) {
    if (e.which === 27) {
      // ESC
      this.get('controller').send('hitEsc');
      return false;
    } else if (e.which === 13 && (e.ctrlKey || e.metaKey)) {
      // CTRL+ENTER or CMD+ENTER
      this.get('controller').send('save');
      return false;
    }
  },

  _enableResizing: function() {
    var $replyControl = $('#reply-control'),
        self = this;
    $replyControl.DivResizer({
      resize: this.resize,
      onDrag: function (sizePx) { self.movePanels.apply(self, [sizePx]); }
    });
    Discourse.TransitionHelper.after($replyControl, this.resize);
    this.ensureMaximumDimensionForImagesInPreview();
    this.set('controller.view', this);
  }.on('didInsertElement'),

  _unlinkView: function() {
    this.set('controller.view', null);
  }.on('willDestroyElement'),

  ensureMaximumDimensionForImagesInPreview: function() {
    // This enforce maximum dimensions of images in the preview according
    // to the current site settings.
    // For interactivity, we immediately insert the locally cooked version
    // of the post into the stream when the user hits reply. We therefore also
    // need to enforce these rules on the .cooked version.
    // Meanwhile, the server is busy post-processing the post and generating thumbnails.
    var style = Discourse.Mobile.mobileView ?
                'max-width: 100%; height: auto;' :
                'max-width:' + Discourse.SiteSettings.max_image_width + 'px;' +
                'max-height:' + Discourse.SiteSettings.max_image_height + 'px;';

    $('<style>#wmd-preview img:not(.thumbnail), .cooked img:not(.thumbnail) {' + style + '}</style>').appendTo('head');
  },

  click: function() {
    this.get('controller').send('openIfDraft');
  },

  // Called after the preview renders. Debounced for performance
  afterRender: function() {
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
      Discourse.Mention.paint(e);
    });

    this.trigger('previewRefreshed', $wmdPreview);
  },

  initEditor: function() {
    // not quite right, need a callback to pass in, meaning this gets called once,
    // but if you start replying to another topic it will get the avatars wrong
    var $wmdInput, editor, self = this;
    this.wmdInput = $wmdInput = $('#wmd-input');
    if ($wmdInput.length === 0 || $wmdInput.data('init') === true) return;

    $LAB.script(assetPath('defer/html-sanitizer-bundle'));
    ComposerView.trigger("initWmdEditor");

    var template = this.container.lookupFactory('view:user-selector').templateFunction();
    $wmdInput.data('init', true);
    $wmdInput.autocomplete({
      template: template,
      dataSource: function(term) {
        return Discourse.UserSearch.search({
          term: term,
          topicId: self.get('controller.controllers.topic.model.id'),
          include_groups: true
        });
      },
      key: "@",
      transformComplete: function(v) {
          if (v.username) {
            return v.username;
          } else {
            return v.usernames.join(", @");
          }
        }
    });

    this.editor = editor = Discourse.Markdown.createEditor({
      lookupAvatarByPostNumber: function(postNumber) {
        var posts = self.get('controller.controllers.topic.postStream.posts');
        if (posts) {
          var quotedPost = posts.findProperty("post_number", postNumber);
          if (quotedPost) {
            return Discourse.Utilities.tinyAvatar(quotedPost.get("avatar_template"));
          }
        }
      }
    });

    // HACK to change the upload icon of the composer's toolbar
    if (!Discourse.Utilities.allowsAttachments()) {
      Em.run.scheduleOnce("afterRender", function() {
        $("#wmd-image-button").addClass("image-only");
      });
    }

    this.editor.hooks.insertImageDialog = function(callback) {
      callback(null);
      self.get('controller').send('showUploadSelector', self);
      return true;
    };

    this.editor.hooks.onPreviewRefresh = function() {
      return self.afterRender();
    };

    this.editor.run();
    this.set('editor', this.editor);
    this.loadingChanged();

    var saveDraft = Discourse.debounce((function() {
      return self.get('controller').saveDraft();
    }), 2000);

    $wmdInput.keyup(function() {
      saveDraft();
      return true;
    });

    var $replyTitle = $('#reply-title');

    $replyTitle.keyup(function() {
      saveDraft();
      // removes the red background once the requirements are met
      if (self.get('model.missingTitleCharacters') <= 0) {
        $replyTitle.removeClass("requirements-not-met");
      }
      return true;
    });

    // when the title field loses the focus...
    $replyTitle.blur(function(){
      // ...and the requirements are not met (ie. the minimum number of characters)
      if (self.get('model.missingTitleCharacters') > 0) {
        // then, "redify" the background
        $replyTitle.toggleClass("requirements-not-met", true);
      }
    });

    // in case it's still bound somehow
    this._unbindUploadTarget();

    var $uploadTarget = $('#reply-control');

    $uploadTarget.fileupload({
      url: Discourse.getURL('/uploads'),
      dataType: 'json'
    });

    // submit - this event is triggered for each upload
    $uploadTarget.on('fileuploadsubmit', function (e, data) {
      var result = Discourse.Utilities.validateUploadedFiles(data.files);
      // reset upload status when everything is ok
      if (result) self.setProperties({ uploadProgress: 0, isUploading: true });
      return result;
    });

    // send - this event is triggered when the upload request is about to start
    $uploadTarget.on('fileuploadsend', function (e, data) {
      // hide the "file selector" modal
      self.get('controller').send('closeModal');
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
      self.set('uploadProgress', progress);
    });

    // done
    $uploadTarget.on('fileuploaddone', function (e, data) {
      // make sure we have a url
      if (data.result.url) {
        var markdown = Discourse.Utilities.getUploadMarkdown(data.result);
        // appends a space at the end of the inserted markdown
        self.addMarkdown(markdown + " ");
        self.set('isUploading', false);
      } else {
        bootbox.alert(I18n.t('post.errors.upload'));
      }
    });

    // fail
    $uploadTarget.on('fileuploadfail', function (e, data) {
      // hide upload status
      self.set('isUploading', false);
      // display an error message
      Discourse.Utilities.displayErrorForUpload(data);
    });

    // contenteditable div hack for getting image paste to upload working in
    // Firefox. This is pretty dangerous because it can potentially break
    // Ctrl+v to paste so we should be conservative about what browsers this runs
    // in.
    var uaMatch = navigator.userAgent.match(/Firefox\/(\d+)\.\d/);
    if (uaMatch && parseInt(uaMatch[1]) >= 24) {
      self.$().append( Ember.$("<div id='contenteditable' contenteditable='true' style='height: 0; width: 0; overflow: hidden'></div>") );
      self.$("textarea").off('keydown.contenteditable');
      self.$("textarea").on('keydown.contenteditable', function(event) {
        // Catch Ctrl+v / Cmd+v and hijack focus to a contenteditable div. We can't
        // use the onpaste event because for some reason the paste isn't resumed
        // after we switch focus, probably because it is being executed too late.
        if ((event.ctrlKey || event.metaKey) && (event.keyCode === 86)) {
          // Save the current textarea selection.
          var textarea = self.$("textarea")[0],
              selectionStart = textarea.selectionStart,
              selectionEnd   = textarea.selectionEnd;

          // Focus the contenteditable div.
          var contentEditableDiv = self.$('#contenteditable');
          contentEditableDiv.focus();

          // The paste doesn't finish immediately and we don't have any onpaste
          // event, so wait for 100ms which _should_ be enough time.
          setTimeout(function() {
            var pastedImg  = contentEditableDiv.find('img');

            if ( pastedImg.length === 1 ) {
              pastedImg.remove();
            }

            // For restoring the selection.
            textarea.focus();
            var textareaContent = $(textarea).val(),
                startContent = textareaContent.substring(0, selectionStart),
                endContent = textareaContent.substring(selectionEnd);

            var restoreSelection = function(pastedText) {
              $(textarea).val( startContent + pastedText + endContent );
              textarea.selectionStart = selectionStart + pastedText.length;
              textarea.selectionEnd = textarea.selectionStart;
            };

            if (contentEditableDiv.html().length > 0) {
              // If the image wasn't the only pasted content we just give up and
              // fall back to the original pasted text.
              contentEditableDiv.find("br").replaceWith("\n");
              restoreSelection(contentEditableDiv.text());
            } else {
              // Depending on how the image is pasted in, we may get either a
              // normal URL or a data URI. If we get a data URI we can convert it
              // to a Blob and upload that, but if it is a regular URL that
              // operation is prevented for security purposes. When we get a regular
              // URL let's just create an <img> tag for the image.
              var imageSrc = pastedImg.attr('src');

              if (imageSrc.match(/^data:image/)) {
                // Restore the cursor position, and remove any selected text.
                restoreSelection("");

                // Create a Blob to upload.
                var image = new Image();
                image.onload = function() {
                  // Create a new canvas.
                  var canvas = document.createElementNS('http://www.w3.org/1999/xhtml', 'canvas');
                  canvas.height = image.height;
                  canvas.width = image.width;
                  var ctx = canvas.getContext('2d');
                  ctx.drawImage(image, 0, 0);

                  canvas.toBlob(function(blob) {
                    $uploadTarget.fileupload('add', {files: blob});
                  });
                };
                image.src = imageSrc;
              } else {
                restoreSelection("<img src='" + imageSrc + "'>");
              }
            }

            contentEditableDiv.html('');
          }, 100);
        }
      });
    }

    // need to wait a bit for the "slide up" transition of the composer
    // we could use .on("transitionend") but it's not firing when the transition isn't completed :(
    Em.run.later(function() {
      self.resize();
      self.refreshPreview();
      if ($replyTitle.length) {
        $replyTitle.putCursorAtEnd();
      } else {
        $wmdInput.putCursorAtEnd();
      }
      self.appEvents.trigger("composer:opened");
    }, 400);
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
      var $img = $(e),
          src = $img.prop('src');

      if (src && src.length) {
        result[src] = { width: $img.width(), height: $img.height() };
      }
    });
    return result;
  },

  childDidInsertElement: function() {
    return this.initEditor();
  },

  childWillDestroyElement: function() {
    var self = this;

    this._unbindUploadTarget();

    Em.run.next(function() {
      $('#main-outlet').css('padding-bottom', 0);
      // need to wait a bit for the "slide down" transition of the composer
      Em.run.later(function() {
        self.appEvents.trigger("composer:closed");
      }, 400);
    });
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
  }.property('model.reply', 'model.replyLength', 'model.missingReplyCharacters', 'model.minimumPostLength'),

  _unbindUploadTarget: function() {
    var $uploadTarget = $('#reply-control');
    $uploadTarget.fileupload('destroy');
    $uploadTarget.off();
  }
});

RSVP.EventTarget.mixin(ComposerView);

export default ComposerView;
