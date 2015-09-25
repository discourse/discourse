import userSearch from 'discourse/lib/user-search';
import afterTransition from 'discourse/lib/after-transition';
import loadScript from 'discourse/lib/load-script';
import positioningWorkaround from 'discourse/lib/safari-hacks';
import debounce from 'discourse/lib/debounce';
import { linkSeenMentions, fetchUnseenMentions } from 'discourse/lib/link-mentions';
import { headerHeight } from 'discourse/views/header';

const ComposerView = Ember.View.extend(Ember.Evented, {
  _lastKeyTimeout: null,
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
      this.$('.wmd-input, #reply-title').prop('disabled', 'disabled');
    } else {
      this.$('.wmd-input, #reply-title').prop('disabled', '');
    }
  }.observes('loading'),

  postMade: function() {
    return !Ember.isEmpty(this.get('model.createdPost')) ? 'created-post' : null;
  }.property('model.createdPost'),

  refreshPreview: debounce(function() {
    if (this.editor) {
      this.editor.refreshPreview();
    }
  }, 30),

  observeReplyChanges: function() {
    if (this.get('model.hidePreview')) return;
    Ember.run.scheduleOnce('afterRender', this, 'refreshPreview');
  }.observes('model.reply', 'model.hidePreview'),

  movePanels(sizePx) {
    $('#main-outlet').css('padding-bottom', sizePx);
    $('.composer-popup').css('bottom', sizePx);
    // signal the progress bar it should move!
    this.appEvents.trigger("composer:resized");
  },

  resize: function() {
    Ember.run.scheduleOnce('afterRender', () => {
      let h = $('#reply-control').height() || 0;
      this.movePanels(h + "px");

      // Figure out the size of the fields
      const $fields = this.$('.composer-fields');
      let pos = $fields.position();

      if (pos) {
        this.$('.wmd-controls').css('top', $fields.height() + pos.top + 5);
      }

      // get the submit panel height
      pos = this.$('.submit-panel').position();
      if (pos) {
        this.$('.wmd-controls').css('bottom', h - pos.top + 7);
      }

    });
  }.observes('model.composeState', 'model.action'),

  keyUp() {
    const controller = this.get('controller');
    controller.checkReplyLength();

    this.get('controller.model').typing();

    const lastKeyUp = new Date();
    this.set('lastKeyUp', lastKeyUp);

    // One second from now, check to see if the last key was hit when
    // we recorded it. If it was, the user paused typing.
    const self = this;

    Ember.run.cancel(this._lastKeyTimeout);
    this._lastKeyTimeout = Ember.run.later(function() {
      if (lastKeyUp !== self.get('lastKeyUp')) return;

      // Search for similar topics if the user pauses typing
      controller.findSimilarTopics();
    }, 1000);
  },

  keyDown(e) {
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
    const $replyControl = $('#reply-control');

    const runResize = () => {
      Ember.run(() => this.resize());
    };

    $replyControl.DivResizer({
      maxHeight(winHeight) {
        return winHeight - headerHeight();
      },
      resize: runResize,
      onDrag: (sizePx) => this.movePanels(sizePx)
    });

    afterTransition($replyControl, runResize);
    this.set('controller.view', this);

    positioningWorkaround(this.$());
  }.on('didInsertElement'),

  _unlinkView: function() {
    this.set('controller.view', null);
  }.on('willDestroyElement'),

  click() {
    this.get('controller').send('openIfDraft');
  },

  // Called after the preview renders. Debounced for performance
  afterRender() {
    if (this._state !== "inDOM") { return; }

    const $wmdPreview = this.$('.wmd-preview');
    if ($wmdPreview.length === 0) return;

    const post = this.get('model.post');
    let refresh = false;

    // If we are editing a post, we'll refresh its contents once. This is a feature that
    // allows a user to refresh its contents once.
    if (post && !post.get('refreshedPost')) {
      refresh = true;
      post.set('refreshedPost', true);
    }

    // Load the post processing effects
    $('a.onebox', $wmdPreview).each(function(i, e) {
      Discourse.Onebox.load(e, refresh);
    });

    const unseen = linkSeenMentions($wmdPreview, this.siteSettings);
    if (unseen.length) {
      Ember.run.debounce(this, this._renderUnseen, $wmdPreview, unseen, 500);
    }

    this.trigger('previewRefreshed', $wmdPreview);
  },

  _renderUnseen: function($wmdPreview, unseen) {
    fetchUnseenMentions($wmdPreview, unseen, this.siteSettings).then(() => {
      linkSeenMentions($wmdPreview, this.siteSettings);
      this.trigger('previewRefreshed', $wmdPreview);
    });
  },

  _applyEmojiAutocomplete() {
    if (!this.siteSettings.enable_emoji) { return; }

    const template = this.container.lookup('template:emoji-selector-autocomplete.raw');
    this.$('.wmd-input').autocomplete({
      template: template,
      key: ":",
      transformComplete(v) { return v.code + ":"; },
      dataSource(term){
        return new Ember.RSVP.Promise(function(resolve) {
          const full = ":" + term;
          term = term.toLowerCase();

          if (term === "") {
            return resolve(["smile", "smiley", "wink", "sunny", "blush"]);
          }

          if (Discourse.Emoji.translations[full]) {
            return resolve([Discourse.Emoji.translations[full]]);
          }

          const options = Discourse.Emoji.search(term, {maxResults: 5});

          return resolve(options);
        }).then(function(list) {
          return list.map(function(i) {
            return {code: i, src: Discourse.Emoji.urlFor(i)};
          });
        });
      }
    });
  },

  initEditor() {
    // not quite right, need a callback to pass in, meaning this gets called once,
    // but if you start replying to another topic it will get the avatars wrong
    let $wmdInput;
    const self = this;
    const controller = this.get('controller');

    this.wmdInput = $wmdInput = this.$('.wmd-input');
    if ($wmdInput.length === 0 || $wmdInput.data('init') === true) return;

    loadScript('defer/html-sanitizer-bundle');
    ComposerView.trigger("initWmdEditor");
    this._applyEmojiAutocomplete();

    const template = this.container.lookup('template:user-selector-autocomplete.raw');
    $wmdInput.data('init', true);
    $wmdInput.autocomplete({
      template: template,
      dataSource(term) {
        return userSearch({
          term: term,
          topicId: controller.get('controllers.topic.model.id'),
          includeGroups: true
        });
      },
      key: "@",
      transformComplete(v) {
        return v.username ? v.username : v.usernames.join(", @");
      }
    });


    const options ={
      containerElement: this.element,
      lookupAvatarByPostNumber(postNumber, topicId) {
        const posts = controller.get('controllers.topic.model.postStream.posts');
        if (posts && topicId === controller.get('controllers.topic.model.id')) {
          const quotedPost = posts.findProperty("post_number", postNumber);
          if (quotedPost) {
            return Discourse.Utilities.tinyAvatar(quotedPost.get('avatar_template'));
          }
        }
      }
    };

    const showOptions = controller.get('canWhisper');
    if (showOptions) {
      options.appendButtons = [{
        id: 'wmd-composer-options',
        description: I18n.t("composer.options"),
        execute() {
          const toolbarPos = self.$('.wmd-controls').position();
          const pos = self.$('.wmd-composer-options').position();

          const location = {
            position: "absolute",
            left: toolbarPos.left + pos.left,
            top: toolbarPos.top + pos.top,
          };
          controller.send('showOptions', location);
        }
      }];
    }

    this.editor = Discourse.Markdown.createEditor(options);

    // HACK to change the upload icon of the composer's toolbar
    if (!Discourse.Utilities.allowsAttachments()) {
      Em.run.scheduleOnce("afterRender", function() {
        $("#wmd-image-button").addClass("image-only");
      });
    }

    this.editor.hooks.insertImageDialog = function(callback) {
      callback(null);
      controller.send('showUploadSelector', self);
      return true;
    };

    this.editor.hooks.onPreviewRefresh = function() {
      return self.afterRender();
    };

    this.editor.run();
    this.set('editor', this.editor);
    this.loadingChanged();

    const saveDraft = debounce((function() {
      return controller.saveDraft();
    }), 2000);

    $wmdInput.keyup(function() {
      saveDraft();
      return true;
    });

    const $replyTitle = $('#reply-title');

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

    const $uploadTarget = $("#reply-control"),
          csrf = Discourse.Session.currentProp("csrfToken"),
          reset = () => this.setProperties({ uploadProgress: 0, isUploading: false });

    var cancelledByTheUser;

    this.messageBus.subscribe("/uploads/composer", upload => {
      // reset upload state
      reset();
      // replace upload placeholder
      if (upload && upload.url) {
        if (!cancelledByTheUser) {
          const uploadPlaceholder = Discourse.Utilities.getUploadPlaceholder(),
                markdown = Discourse.Utilities.getUploadMarkdown(upload);
          this.replaceMarkdown(uploadPlaceholder, markdown);
        }
      } else {
        Discourse.Utilities.displayErrorForUpload(upload);
      }
    });

    $uploadTarget.fileupload({
      url: Discourse.getURL("/uploads.json?client_id=" + this.messageBus.clientId + "&authenticity_token=" + encodeURIComponent(csrf)),
      dataType: "json",
      pasteZone: $uploadTarget,
    });

    $uploadTarget.on("fileuploadsubmit", (e, data) => {
      const isValid = Discourse.Utilities.validateUploadedFiles(data.files);
      data.formData = { type: "composer" };
      this.setProperties({ uploadProgress: 0, isUploading: isValid });
      return isValid;
    });

    $uploadTarget.on("fileuploadsend", (e, data) => {
      // hide the "file selector" modal
      controller.send("closeModal");
      // deal with cancellation
      cancelledByTheUser = false;
      // add upload placeholder
      const uploadPlaceholder = Discourse.Utilities.getUploadPlaceholder();
      this.addMarkdown(uploadPlaceholder);

      if (data["xhr"]) {
        const jqHXR = data.xhr();
        if (jqHXR) {
          // need to wait for the link to show up in the DOM
          Em.run.schedule("afterRender", () => {
            const $cancel = $("#cancel-file-upload");
            $cancel.on("click", () => {
              if (jqHXR) {
                // signal the upload was cancelled by the user
                cancelledByTheUser = true;
                // immediately remove upload placeholder
                this.replaceMarkdown(uploadPlaceholder, "");
                // might trigger a "fileuploadfail" event with status = 0
                jqHXR.abort();
                // make sure we always reset the uploading status
                reset();
              }
              // unbind
              $cancel.off("click");
            });
          });
        }
      }
    });

    $uploadTarget.on("fileuploadprogressall", (e, data) => {
      const progress = parseInt(data.loaded / data.total * 100, 10);
      this.set("uploadProgress", progress);
    });

    $uploadTarget.on("fileuploadfail", (e, data) => {
      // reset upload state
      reset();

      if (!cancelledByTheUser) {
        // remove upload placeholder when there's a failure
        const uploadPlaceholder = Discourse.Utilities.getUploadPlaceholder();
        this.replaceMarkdown(uploadPlaceholder, "");
        // display the error
        Discourse.Utilities.displayErrorForUpload(data);
      }
    });

    // contenteditable div hack for getting image paste to upload working in
    // Firefox. This is pretty dangerous because it can potentially break
    // Ctrl+v to paste so we should be conservative about what browsers this runs
    // in.
    const uaMatch = navigator.userAgent.match(/Firefox\/(\d+)\.\d/);
    if (uaMatch && parseInt(uaMatch[1]) >= 24) {
      self.$().append( Ember.$("<div id='contenteditable' contenteditable='true' style='height: 0; width: 0; overflow: hidden'></div>") );
      self.$("textarea").off('keydown.contenteditable');
      self.$("textarea").on('keydown.contenteditable', function(event) {
        // Catch Ctrl+v / Cmd+v and hijack focus to a contenteditable div. We can't
        // use the onpaste event because for some reason the paste isn't resumed
        // after we switch focus, probably because it is being executed too late.
        if ((event.ctrlKey || event.metaKey) && (event.keyCode === 86)) {
          // Save the current textarea selection.
          const textarea = self.$("textarea")[0],
              selectionStart = textarea.selectionStart,
              selectionEnd   = textarea.selectionEnd;

          // Focus the contenteditable div.
          const contentEditableDiv = self.$('#contenteditable');
          contentEditableDiv.focus();

          // The paste doesn't finish immediately and we don't have any onpaste
          // event, so wait for 100ms which _should_ be enough time.
          setTimeout(function() {
            const pastedImg  = contentEditableDiv.find('img');

            if ( pastedImg.length === 1 ) {
              pastedImg.remove();
            }

            // For restoring the selection.
            textarea.focus();
            const textareaContent = $(textarea).val(),
                startContent = textareaContent.substring(0, selectionStart),
                endContent = textareaContent.substring(selectionEnd);

            const restoreSelection = function(pastedText) {
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
              const imageSrc = pastedImg.attr('src');

              if (imageSrc.match(/^data:image/)) {
                // Restore the cursor position, and remove any selected text.
                restoreSelection("");

                // Create a Blob to upload.
                const image = new Image();
                image.onload = function() {
                  // Create a new canvas.
                  const canvas = document.createElementNS('http://www.w3.org/1999/xhtml', 'canvas');
                  canvas.height = image.height;
                  canvas.width = image.width;
                  const ctx = canvas.getContext('2d');
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

    if (Discourse.Mobile.mobileView) {
      $(".mobile-file-upload").on("click.uploader", function () {
        // redirect the click on the hidden file input
        $("#mobile-uploader").click();
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

  addMarkdown(text) {
    const ctrl = this.$('.wmd-input').get(0),
          reply = this.get('model.reply'),
          caretPosition = Discourse.Utilities.caretPosition(ctrl);

    this.set('model.reply', reply.substring(0, caretPosition) + text + reply.substring(caretPosition, reply.length));

    Em.run.schedule('afterRender', () => Discourse.Utilities.setCaretPosition(ctrl, caretPosition + text.length));
  },

  replaceMarkdown(old, text) {
    const ctrl = this.$(".wmd-input").get(0),
          reply = this.get("model.reply"),
          beforeCaretPosition = Discourse.Utilities.caretPosition(ctrl),
          afterCaretPosition = beforeCaretPosition <= reply.indexOf(old) ? beforeCaretPosition :  beforeCaretPosition - old.length + text.length;

    this.set("model.reply", reply.replace(old, text));

    Ember.run.schedule("afterRender", () => Discourse.Utilities.setCaretPosition(ctrl, afterCaretPosition));
  },

  // Uses javascript to get the image sizes from the preview, if present
  imageSizes() {
    const result = {};
    this.$('.wmd-preview img').each(function(i, e) {
      const $img = $(e),
          src = $img.prop('src');

      if (src && src.length) {
        result[src] = { width: $img.width(), height: $img.height() };
      }
    });
    return result;
  },

  childDidInsertElement() {
    this.initEditor();

    // Disable links in the preview
    this.$('.wmd-preview').on('click.preview', (e) => {
      e.preventDefault();
      return false;
    });
  },

  childWillDestroyElement() {
    this._unbindUploadTarget();

    this.$('.wmd-preview').off('click.preview');

    const self = this;

    Em.run.next(() => {
      $('#main-outlet').css('padding-bottom', 0);
      // need to wait a bit for the "slide down" transition of the composer
      Em.run.later(() => {
        if (self.get('composeState') !== Discourse.Composer.CLOSED) {
          $('#main-outlet').css('padding-bottom', $('#reply-control').height());
        }

        this.appEvents.trigger("composer:closed");
      }, 400);
    });
  },

  _unbindUploadTarget() {
    this.messageBus.unsubscribe("/uploads/composer");
    const $uploadTarget = $("#reply-control");
    try { $uploadTarget.fileupload("destroy"); }
    catch (e) { /* wasn't initialized yet */ }
    $uploadTarget.off();
  },

  titleValidation: function() {
    const titleLength = this.get('model.titleLength'),
        missingChars = this.get('model.missingTitleCharacters');
    let reason;
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
    const postType = this.get('model.post.post_type');
    if (postType === this.site.get('post_types.small_action')) { return; }

    const replyLength = this.get('model.replyLength'),
          missingChars = this.get('model.missingReplyCharacters');

    let reason;
    if (replyLength < 1) {
      reason = I18n.t('composer.error.post_missing');
    } else if (missingChars > 0) {
      reason = I18n.t('composer.error.post_length', {min: this.get('model.minimumPostLength')});
      const tl = Discourse.User.currentProp("trust_level");
      if (tl === 0 || tl === 1) {
        reason += "<br/>" + I18n.t('composer.error.try_like');
      }
    }

    if (reason) {
      return Discourse.InputValidation.create({ failed: true, reason });
    }
  }.property('model.reply', 'model.replyLength', 'model.missingReplyCharacters', 'model.minimumPostLength'),
});

RSVP.EventTarget.mixin(ComposerView);

export default ComposerView;
