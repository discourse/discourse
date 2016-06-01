import userSearch from 'discourse/lib/user-search';
import { default as computed, on } from 'ember-addons/ember-computed-decorators';
import { linkSeenMentions, fetchUnseenMentions } from 'discourse/lib/link-mentions';
import { linkSeenCategoryHashtags, fetchUnseenCategoryHashtags } from 'discourse/lib/link-category-hashtags';
import { fetchUnseenTagHashtags, linkSeenTagHashtags } from 'discourse/lib/link-tag-hashtag';

export default Ember.Component.extend({
  classNames: ['wmd-controls'],
  classNameBindings: ['showToolbar:toolbar-visible', ':wmd-controls', 'showPreview', 'showPreview::hide-preview'],

  uploadProgress: 0,
  showPreview: true,
  _xhr: null,

  @computed
  uploadPlaceholder() {
    return `[${I18n.t('uploading')}]() `;
  },

  @on('init')
  _setupPreview() {
    const val = (this.site.mobileView ? false : (this.keyValueStore.get('composer.showPreview') || 'true'));
    this.set('showPreview', val === 'true');
  },

  @computed('showPreview')
  toggleText: function(showPreview) {
    return showPreview ? I18n.t('composer.hide_preview') : I18n.t('composer.show_preview');
  },

  _renderUnseenTagHashtags($preview, unseen) {
    fetchUnseenTagHashtags(unseen).then(() => {
      linkSeenTagHashtags($preview);
    });
  },

  @on('previewRefreshed')
  paintTagHashtags($preview) {
    if (!this.siteSettings.tagging_enabled) { return; }

    const unseenTagHashtags = linkSeenTagHashtags($preview);
    if (unseenTagHashtags.length) {
      Ember.run.debounce(this, this._renderUnseenTagHashtags, $preview, unseenTagHashtags, 500);
    }
  },

  @computed
  markdownOptions() {
    return {
      lookupAvatarByPostNumber: (postNumber, topicId) => {
        const topic = this.get('topic');
        if (!topic) { return; }

        const posts = topic.get('postStream.posts');
        if (posts && topicId === topic.get('id')) {
          const quotedPost = posts.findProperty("post_number", postNumber);
          if (quotedPost) {
            return Discourse.Utilities.tinyAvatar(quotedPost.get('avatar_template'));
          }
        }
      }
    };
  },

  @on('didInsertElement')
  _composerEditorInit() {
    const topicId = this.get('topic.id');
    const template = this.container.lookup('template:user-selector-autocomplete.raw');
    const $input = this.$('.d-editor-input');
    $input.autocomplete({
      template,
      dataSource: term => userSearch({ term, topicId, includeGroups: true }),
      key: "@",
      transformComplete: v => v.username || v.name
    });

    $input.on('scroll', () => Ember.run.throttle(this, this._syncEditorAndPreviewScroll, 20));

    // Focus on the body unless we have a title
    if (!this.get('composer.canEditTitle') && !this.capabilities.isIOS) {
      this.$('.d-editor-input').putCursorAtEnd();
    }

    this._bindUploadTarget();
    this.appEvents.trigger('composer:will-open');
  },

  @computed('composer.reply', 'composer.replyLength', 'composer.missingReplyCharacters', 'composer.minimumPostLength', 'lastValidatedAt')
  validation(reply, replyLength, missingReplyCharacters, minimumPostLength, lastValidatedAt) {
    const postType = this.get('composer.post.post_type');
    if (postType === this.site.get('post_types.small_action')) { return; }

    let reason;
    if (replyLength < 1) {
      reason = I18n.t('composer.error.post_missing');
    } else if (missingReplyCharacters > 0) {
      reason = I18n.t('composer.error.post_length', {min: minimumPostLength});
      const tl = Discourse.User.currentProp("trust_level");
      if (tl === 0 || tl === 1) {
        reason += "<br/>" + I18n.t('composer.error.try_like');
      }
    }

    if (reason) {
      return Discourse.InputValidation.create({ failed: true, reason, lastShownAt: lastValidatedAt });
    }
  },

  _syncEditorAndPreviewScroll() {
    const $input = this.$('.d-editor-input');
    if (!$input) { return; }

    const $preview = this.$('.d-editor-preview');

    if ($input.scrollTop() === 0) {
      $preview.scrollTop(0);
      return;
    }

    const inputHeight = $input[0].scrollHeight;
    const previewHeight = $preview[0].scrollHeight;
    if (($input.height() + $input.scrollTop() + 100) > inputHeight) {
      // cheat, special case for bottom
      $preview.scrollTop(previewHeight);
      return;
    }

    const scrollPosition = $input.scrollTop();
    const factor = previewHeight / inputHeight;
    const desired = scrollPosition * factor;
    $preview.scrollTop(desired + 50);
  },

  _renderUnseenMentions: function($preview, unseen) {
    fetchUnseenMentions($preview, unseen).then(() => {
      linkSeenMentions($preview, this.siteSettings);
      this._warnMentionedGroups($preview);
    });
  },

  _renderUnseenCategoryHashtags: function($preview, unseen) {
    fetchUnseenCategoryHashtags(unseen).then(() => {
      linkSeenCategoryHashtags($preview);
    });
  },

  _warnMentionedGroups($preview) {
    Ember.run.scheduleOnce('afterRender', () => {
      this._warnedMentions = this._warnedMentions || [];
      var found = [];
      $preview.find('.mention-group.notify').each((idx,e) => {
        const $e = $(e);
        var name = $e.data('name');
        found.push(name);
        if (this._warnedMentions.indexOf(name) === -1){
          this._warnedMentions.push(name);
          this.sendAction('groupsMentioned', [{name: name, user_count: $e.data('mentionable-user-count')}]);
        }
      });

      this._warnedMentions = found;
    });
  },

  _resetUpload(removePlaceholder) {
    this._validUploads--;
    if (this._validUploads === 0) {
      this.setProperties({ uploadProgress: 0, isUploading: false, isCancellable: false });
    }
    if (removePlaceholder) {
      this.set('composer.reply', this.get('composer.reply').replace(this.get('uploadPlaceholder'), ""));
    }
  },

  _bindUploadTarget() {
    this._unbindUploadTarget(); // in case it's still bound, let's clean it up first

    const $element = this.$();
    const csrf = this.session.get('csrfToken');
    const uploadPlaceholder = this.get('uploadPlaceholder');

    $element.fileupload({
      url: Discourse.getURL(`/uploads.json?client_id=${this.messageBus.clientId}&authenticity_token=${encodeURIComponent(csrf)}`),
      dataType: "json",
      pasteZone: $element,
    });

    $element.on('fileuploadsubmit', (e, data) => {
      const isUploading = Discourse.Utilities.validateUploadedFiles(data.files);
      data.formData = { type: "composer" };
      this.setProperties({ uploadProgress: 0, isUploading });
      return isUploading;
    });

    $element.on("fileuploadprogressall", (e, data) => {
      this.set("uploadProgress", parseInt(data.loaded / data.total * 100, 10));
    });

    $element.on("fileuploadsend", (e, data) => {
      this._validUploads++;
      // add upload placeholders (as much placeholders as valid files dropped)
      const placeholder = _.times(this._validUploads, () => uploadPlaceholder).join("\n");
      this.appEvents.trigger('composer:insert-text', placeholder);

      if (data.xhr && data.originalFiles.length === 1) {
        this.set("isCancellable", true);
        this._xhr = data.xhr();
      }
    });

    $element.on("fileuploadfail", (e, data) => {
      this._resetUpload(true);

      const userCancelled = this._xhr && this._xhr._userCancelled;
      this._xhr = null;

      if (!userCancelled) {
        Discourse.Utilities.displayErrorForUpload(data);
      }
    });

    this.messageBus.subscribe("/uploads/composer", upload => {
      // replace upload placeholder
      if (upload && upload.url) {
        if (!this._xhr || !this._xhr._userCancelled) {
          const markdown = Discourse.Utilities.getUploadMarkdown(upload);
          this.set('composer.reply', this.get('composer.reply').replace(uploadPlaceholder, markdown));
          this._resetUpload(false);
        } else {
          this._resetUpload(true);
        }
      } else {
        this._resetUpload(true);
        Discourse.Utilities.displayErrorForUpload(upload);
      }
    });

    if (this.site.mobileView) {
      this.$(".mobile-file-upload").on("click.uploader", function () {
        // redirect the click on the hidden file input
        $("#mobile-uploader").click();
      });
    }

    this._firefoxPastingHack();
  },

  // Believe it or not pasting an image in Firefox doesn't work without this code
  _firefoxPastingHack() {
    const uaMatch = navigator.userAgent.match(/Firefox\/(\d+)\.\d/);
    if (uaMatch && parseInt(uaMatch[1]) >= 24) {
      this.$().append( Ember.$("<div id='contenteditable' contenteditable='true' style='height: 0; width: 0; overflow: hidden'></div>") );
      this.$("textarea").off('keydown.contenteditable');
      this.$("textarea").on('keydown.contenteditable', event => {
        // Catch Ctrl+v / Cmd+v and hijack focus to a contenteditable div. We can't
        // use the onpaste event because for some reason the paste isn't resumed
        // after we switch focus, probably because it is being executed too late.
        if ((event.ctrlKey || event.metaKey) && (event.keyCode === 86)) {
          // Save the current textarea selection.
          const textarea = this.$("textarea")[0];
          const selectionStart = textarea.selectionStart;
          const selectionEnd = textarea.selectionEnd;

          // Focus the contenteditable div.
          const contentEditableDiv = this.$('#contenteditable');
          contentEditableDiv.focus();

          // The paste doesn't finish immediately and we don't have any onpaste
          // event, so wait for 100ms which _should_ be enough time.
          setTimeout(() => {
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
                image.onload = () => {
                  // Create a new canvas.
                  const canvas = document.createElementNS('http://www.w3.org/1999/xhtml', 'canvas');
                  canvas.height = image.height;
                  canvas.width = image.width;
                  const ctx = canvas.getContext('2d');
                  ctx.drawImage(image, 0, 0);

                  canvas.toBlob(blob => this.$().fileupload('add', {files: blob}));
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
  },

  @on('willDestroyElement')
  _unbindUploadTarget() {
    this._validUploads = 0;
    this.$(".mobile-file-upload").off("click.uploader");
    this.messageBus.unsubscribe("/uploads/composer");
    const $uploadTarget = this.$();
    try { $uploadTarget.fileupload("destroy"); }
    catch (e) { /* wasn't initialized yet */ }
    $uploadTarget.off();
  },

  @on('willDestroyElement')
  _composerClosed() {
    this.appEvents.trigger('composer:will-close');
    Ember.run.next(() => {
      $('#main-outlet').css('padding-bottom', 0);
      // need to wait a bit for the "slide down" transition of the composer
      Ember.run.later(() => this.appEvents.trigger("composer:closed"), 400);
    });
  },

  actions: {
    importQuote(toolbarEvent) {
      this.sendAction('importQuote', toolbarEvent);
    },

    cancelUpload() {
      if (this._xhr) {
        this._xhr._userCancelled = true;
        this._xhr.abort();
      }
      this._resetUpload(true);
    },

    showOptions() {
      // long term we want some smart positioning algorithm in popup-menu
      // the problem is that positioning in a fixed panel is a nightmare
      // cause offsetParent can end up returning a fixed element and then
      // using offset() is not going to work, so you end up needing special logic
      // especially since we allow for negative .top, provided there is room on screen
      const myPos = this.$().position();
      const buttonPos = this.$('.options').position();

      const popupHeight = $('#reply-control .popup-menu').height();
      const popupWidth = $('#reply-control .popup-menu').width();

      var top = myPos.top + buttonPos.top - 15;
      var left = myPos.left + buttonPos.left - (popupWidth/2);

      const composerPos = $('#reply-control').position();

      if (composerPos.top + top - popupHeight < 0) {
        top = top + popupHeight + this.$('.options').height() + 50;
      }

      var replyWidth = $('#reply-control').width();
      if (left + popupWidth > replyWidth) {
        left = replyWidth - popupWidth - 40;
      }

      this.sendAction('showOptions', { position: "absolute",
                                       left: left,
                                       top: top });
    },

    showUploadModal(toolbarEvent) {
      this.sendAction('showUploadSelector', toolbarEvent);
    },

    togglePreview() {
      this.toggleProperty('showPreview');
      this.keyValueStore.set({ key: 'composer.showPreview', value: this.get('showPreview') });
    },

    extraButtons(toolbar) {
      toolbar.addButton({
        id: 'quote',
        group: 'fontStyles',
        icon: 'comment-o',
        sendAction: 'importQuote',
        title: 'composer.quote_post_title',
        unshift: true
      });

      toolbar.addButton({
        id: 'upload',
        group: 'insertions',
        icon: 'upload',
        title: 'upload',
        sendAction: 'showUploadModal'
      });

      if (this.get('canWhisper')) {
        toolbar.addButton({
          id: 'options',
          group: 'extras',
          icon: 'gear',
          title: 'composer.options',
          sendAction: 'showOptions'
        });
      }
    },

    previewUpdated($preview) {
      // Paint mentions
      const unseen = linkSeenMentions($preview, this.siteSettings);
      if (unseen.length) {
        Ember.run.debounce(this, this._renderUnseenMentions, $preview, unseen, 500);
      }

      this._warnMentionedGroups($preview);

      // Paint category hashtags
      const unseenHashtags = linkSeenCategoryHashtags($preview);
      if (unseenHashtags.length) {
        Ember.run.debounce(this, this._renderUnseenCategoryHashtags, $preview, unseenHashtags, 500);
      }

      const post = this.get('composer.post');
      let refresh = false;

      // If we are editing a post, we'll refresh its contents once. This is a feature that
      // allows a user to refresh its contents once.
      if (post && !post.get('refreshedPost')) {
        refresh = true;
        post.set('refreshedPost', true);
      }

      // Paint oneboxes
      $('a.onebox', $preview).each((i, e) => Discourse.Onebox.load(e, refresh));
      this.trigger('previewRefreshed', $preview);
    },
  }
});
