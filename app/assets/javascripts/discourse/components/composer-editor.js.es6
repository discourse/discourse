import userSearch from "discourse/lib/user-search";
import {
  default as computed,
  observes,
  on
} from "ember-addons/ember-computed-decorators";
import {
  linkSeenMentions,
  fetchUnseenMentions
} from "discourse/lib/link-mentions";
import {
  linkSeenCategoryHashtags,
  fetchUnseenCategoryHashtags
} from "discourse/lib/link-category-hashtags";
import {
  linkSeenTagHashtags,
  fetchUnseenTagHashtags
} from "discourse/lib/link-tag-hashtag";
import Composer from "discourse/models/composer";
import { load } from "pretty-text/oneboxer";
import { applyInlineOneboxes } from "pretty-text/inline-oneboxer";
import { ajax } from "discourse/lib/ajax";
import InputValidation from "discourse/models/input-validation";
import { findRawTemplate } from "discourse/lib/raw-templates";
import {
  tinyAvatar,
  displayErrorForUpload,
  getUploadMarkdown,
  validateUploadedFiles,
  authorizesOneOrMoreImageExtensions,
  formatUsername,
  clipboardData
} from "discourse/lib/utilities";
import {
  cacheShortUploadUrl,
  resolveAllShortUrls
} from "pretty-text/image-short-url";

const REBUILD_SCROLL_MAP_EVENTS = ["composer:resized", "composer:typed-reply"];

export default Ember.Component.extend({
  classNameBindings: ["showToolbar:toolbar-visible", ":wmd-controls"],

  uploadProgress: 0,
  _xhr: null,
  shouldBuildScrollMap: true,
  scrollMap: null,

  @computed
  uploadPlaceholder() {
    return `[${I18n.t("uploading")}]() `;
  },

  @computed("composer.requiredCategoryMissing")
  replyPlaceholder(requiredCategoryMissing) {
    if (requiredCategoryMissing) {
      return "composer.reply_placeholder_choose_category";
    } else {
      const key = authorizesOneOrMoreImageExtensions()
        ? "reply_placeholder"
        : "reply_placeholder_no_images";
      return `composer.${key}`;
    }
  },

  @computed
  showLink() {
    return (
      this.currentUser && this.currentUser.get("link_posting_access") !== "none"
    );
  },

  @computed("composer.requiredCategoryMissing", "composer.replyLength")
  disableTextarea(requiredCategoryMissing, replyLength) {
    return requiredCategoryMissing && replyLength === 0;
  },

  @observes("composer.uploadCancelled")
  _cancelUpload() {
    if (!this.get("composer.uploadCancelled")) {
      return;
    }
    this.set("composer.uploadCancelled", false);

    if (this._xhr) {
      this._xhr._userCancelled = true;
      this._xhr.abort();
    }
    this._resetUpload(true);
  },

  @computed
  markdownOptions() {
    return {
      previewing: true,

      formatUsername,

      lookupAvatarByPostNumber: (postNumber, topicId) => {
        const topic = this.get("topic");
        if (!topic) {
          return;
        }

        const posts = topic.get("postStream.posts");
        if (posts && topicId === topic.get("id")) {
          const quotedPost = posts.findBy("post_number", postNumber);
          if (quotedPost) {
            return tinyAvatar(quotedPost.get("avatar_template"));
          }
        }
      },

      lookupPrimaryUserGroupByPostNumber: (postNumber, topicId) => {
        const topic = this.get("topic");
        if (!topic) {
          return;
        }

        const posts = topic.get("postStream.posts");
        if (posts && topicId === topic.get("id")) {
          const quotedPost = posts.findBy("post_number", postNumber);
          if (quotedPost) {
            return quotedPost.primary_group_name;
          }
        }
      }
    };
  },

  @on("didInsertElement")
  _composerEditorInit() {
    const topicId = this.get("topic.id");
    const $input = this.$(".d-editor-input");
    const $preview = this.$(".d-editor-preview-wrapper");

    if (this.siteSettings.enable_mentions) {
      $input.autocomplete({
        template: findRawTemplate("user-selector-autocomplete"),
        dataSource: term =>
          userSearch({
            term,
            topicId,
            includeMentionableGroups: true
          }),
        key: "@",
        transformComplete: v => v.username || v.name
      });
    }

    if (this._enableAdvancedEditorPreviewSync()) {
      this._initInputPreviewSync($input, $preview);
    } else {
      $input.on("scroll", () =>
        Ember.run.throttle(
          this,
          this._syncEditorAndPreviewScroll,
          $input,
          $preview,
          20
        )
      );
    }

    // Focus on the body unless we have a title
    if (!this.get("composer.canEditTitle") && !this.capabilities.isIOS) {
      this.$(".d-editor-input").putCursorAtEnd();
    }

    this._bindUploadTarget();
    this.appEvents.trigger("composer:will-open");
  },

  @computed(
    "composer.reply",
    "composer.replyLength",
    "composer.missingReplyCharacters",
    "composer.minimumPostLength",
    "lastValidatedAt"
  )
  validation(
    reply,
    replyLength,
    missingReplyCharacters,
    minimumPostLength,
    lastValidatedAt
  ) {
    const postType = this.get("composer.post.post_type");
    if (postType === this.site.get("post_types.small_action")) {
      return;
    }

    let reason;
    if (replyLength < 1) {
      reason = I18n.t("composer.error.post_missing");
    } else if (missingReplyCharacters > 0) {
      reason = I18n.t("composer.error.post_length", { min: minimumPostLength });
      const tl = Discourse.User.currentProp("trust_level");
      if (tl === 0 || tl === 1) {
        reason += "<br/>" + I18n.t("composer.error.try_like");
      }
    }

    if (reason) {
      return InputValidation.create({
        failed: true,
        reason,
        lastShownAt: lastValidatedAt
      });
    }
  },

  _enableAdvancedEditorPreviewSync() {
    return this.siteSettings.enable_advanced_editor_preview_sync;
  },

  _resetShouldBuildScrollMap() {
    this.set("shouldBuildScrollMap", true);
  },

  _initInputPreviewSync($input, $preview) {
    REBUILD_SCROLL_MAP_EVENTS.forEach(event => {
      this.appEvents.on(event, this, this._resetShouldBuildScrollMap);
    });

    Ember.run.scheduleOnce("afterRender", () => {
      $input.on("touchstart mouseenter", () => {
        if (!$preview.is(":visible")) return;
        $preview.off("scroll");

        $input.on("scroll", () => {
          this._syncScroll(this._syncEditorAndPreviewScroll, $input, $preview);
        });
      });

      $preview.on("touchstart mouseenter", () => {
        $input.off("scroll");

        $preview.on("scroll", () => {
          this._syncScroll(this._syncPreviewAndEditorScroll, $input, $preview);
        });
      });
    });
  },

  _syncScroll($callback, $input, $preview) {
    if (!this.get("scrollMap") || this.get("shouldBuildScrollMap")) {
      this.set("scrollMap", this._buildScrollMap($input, $preview));
      this.set("shouldBuildScrollMap", false);
    }

    Ember.run.throttle(
      this,
      $callback,
      $input,
      $preview,
      this.get("scrollMap"),
      20
    );
  },

  _teardownInputPreviewSync() {
    [this.$(".d-editor-input"), this.$(".d-editor-preview-wrapper")].forEach(
      $element => {
        $element.off("mouseenter touchstart");
        $element.off("scroll");
      }
    );

    REBUILD_SCROLL_MAP_EVENTS.forEach(event => {
      this.appEvents.off(event, this, this._resetShouldBuildScrollMap);
    });
  },

  // Adapted from https://github.com/markdown-it/markdown-it.github.io
  _buildScrollMap($input, $preview) {
    let sourceLikeDiv = $("<div />")
      .css({
        position: "absolute",
        height: "auto",
        visibility: "hidden",
        width: $input[0].clientWidth,
        "font-size": $input.css("font-size"),
        "font-family": $input.css("font-family"),
        "line-height": $input.css("line-height"),
        "white-space": $input.css("white-space")
      })
      .appendTo("body");

    const linesMap = [];
    let numberOfLines = 0;

    $input
      .val()
      .split("\n")
      .forEach(text => {
        linesMap.push(numberOfLines);

        if (text.length === 0) {
          numberOfLines++;
        } else {
          sourceLikeDiv.text(text);

          let height;
          let lineHeight;
          height = parseFloat(sourceLikeDiv.css("height"));
          lineHeight = parseFloat(sourceLikeDiv.css("line-height"));
          numberOfLines += Math.round(height / lineHeight);
        }
      });

    linesMap.push(numberOfLines);
    sourceLikeDiv.remove();

    const previewOffsetTop = $preview.offset().top;
    const offset =
      $preview.scrollTop() -
      previewOffsetTop -
      ($input.offset().top - previewOffsetTop);
    const nonEmptyList = [];
    const scrollMap = [];
    for (let i = 0; i < numberOfLines; i++) {
      scrollMap.push(-1);
    }

    nonEmptyList.push(0);
    scrollMap[0] = 0;

    $preview.find(".preview-sync-line").each((_, element) => {
      let $element = $(element);
      let lineNumber = $element.data("line-number");
      let linesToTop = linesMap[lineNumber];
      if (linesToTop !== 0) {
        nonEmptyList.push(linesToTop);
      }
      scrollMap[linesToTop] = Math.round($element.offset().top + offset);
    });

    nonEmptyList.push(numberOfLines);
    scrollMap[numberOfLines] = $preview[0].scrollHeight;

    let position = 0;

    for (let i = 1; i < numberOfLines; i++) {
      if (scrollMap[i] !== -1) {
        position++;
        continue;
      }

      let top = nonEmptyList[position];
      let bottom = nonEmptyList[position + 1];

      scrollMap[i] = (
        (scrollMap[bottom] * (i - top) + scrollMap[top] * (bottom - i)) /
        (bottom - top)
      ).toFixed(2);
    }

    return scrollMap;
  },

  _syncEditorAndPreviewScroll($input, $preview, scrollMap) {
    if (this._enableAdvancedEditorPreviewSync()) {
      let scrollTop;
      const inputHeight = $input.height();
      const inputScrollHeight = $input[0].scrollHeight;
      const inputClientHeight = $input[0].clientHeight;
      const scrollable = inputScrollHeight > inputClientHeight;

      if (
        scrollable &&
        inputHeight + $input.scrollTop() + 100 > inputScrollHeight
      ) {
        scrollTop = $preview[0].scrollHeight;
      } else {
        const lineHeight = parseFloat($input.css("line-height"));
        const lineNumber = Math.floor($input.scrollTop() / lineHeight);
        scrollTop = scrollMap[lineNumber];
      }

      $preview.stop(true).animate({ scrollTop }, 100, "linear");
    } else {
      if (!$input) {
        return;
      }

      if ($input.scrollTop() === 0) {
        $preview.scrollTop(0);
        return;
      }

      const inputHeight = $input[0].scrollHeight;
      const previewHeight = $preview[0].scrollHeight;

      if ($input.height() + $input.scrollTop() + 100 > inputHeight) {
        // cheat, special case for bottom
        $preview.scrollTop(previewHeight);
        return;
      }

      const scrollPosition = $input.scrollTop();
      const factor = previewHeight / inputHeight;
      const desired = scrollPosition * factor;
      $preview.scrollTop(desired + 50);
    }
  },

  _syncPreviewAndEditorScroll($input, $preview, scrollMap) {
    if (scrollMap.length < 1) return;

    let scrollTop;
    const previewScrollTop = $preview.scrollTop();

    if ($preview.height() + previewScrollTop + 100 > $preview[0].scrollHeight) {
      scrollTop = $input[0].scrollHeight;
    } else {
      const lineHeight = parseFloat($input.css("line-height"));
      scrollTop =
        lineHeight * scrollMap.findIndex(offset => offset > previewScrollTop);
    }

    $input.stop(true).animate({ scrollTop }, 100, "linear");
  },

  _renderUnseenMentions($preview, unseen) {
    // 'Create a New Topic' scenario is not supported (per conversation with codinghorror)
    // https://meta.discourse.org/t/taking-another-1-7-release-task/51986/7
    fetchUnseenMentions(unseen, this.get("composer.topic.id")).then(() => {
      linkSeenMentions($preview, this.siteSettings);
      this._warnMentionedGroups($preview);
      this._warnCannotSeeMention($preview);
    });
  },

  _renderUnseenCategoryHashtags($preview, unseen) {
    fetchUnseenCategoryHashtags(unseen).then(() => {
      linkSeenCategoryHashtags($preview);
    });
  },

  _renderUnseenTagHashtags($preview, unseen) {
    fetchUnseenTagHashtags(unseen).then(() => {
      linkSeenTagHashtags($preview);
    });
  },

  _loadInlineOneboxes(inline) {
    applyInlineOneboxes(inline, ajax);
  },

  _loadOneboxes($oneboxes) {
    const post = this.get("composer.post");
    let refresh = false;

    // If we are editing a post, we'll refresh its contents once.
    if (post && !post.get("refreshedPost")) {
      refresh = true;
      post.set("refreshedPost", true);
    }

    $oneboxes.each((_, o) =>
      load({
        elem: o,
        refresh,
        ajax,
        categoryId: this.get("composer.category.id"),
        topicId: this.get("composer.topic.id")
      })
    );
  },

  _warnMentionedGroups($preview) {
    Ember.run.scheduleOnce("afterRender", () => {
      var found = this.get("warnedGroupMentions") || [];
      $preview.find(".mention-group.notify").each((idx, e) => {
        const $e = $(e);
        var name = $e.data("name");
        if (found.indexOf(name) === -1) {
          this.sendAction("groupsMentioned", [
            {
              name: name,
              user_count: $e.data("mentionable-user-count"),
              max_mentions: $e.data("max-mentions")
            }
          ]);
          found.push(name);
        }
      });

      this.set("warnedGroupMentions", found);
    });
  },

  _warnCannotSeeMention($preview) {
    const composerDraftKey = this.get("composer.draftKey");

    if (
      composerDraftKey === Composer.CREATE_TOPIC ||
      composerDraftKey === Composer.NEW_PRIVATE_MESSAGE_KEY ||
      composerDraftKey === Composer.REPLY_AS_NEW_TOPIC_KEY ||
      composerDraftKey === Composer.REPLY_AS_NEW_PRIVATE_MESSAGE_KEY
    ) {
      return;
    }

    Ember.run.scheduleOnce("afterRender", () => {
      let found = this.get("warnedCannotSeeMentions") || [];

      $preview.find(".mention.cannot-see").each((idx, e) => {
        const $e = $(e);
        let name = $e.data("name");

        if (found.indexOf(name) === -1) {
          // add a delay to allow for typing, so you don't open the warning right away
          // previously we would warn after @bob even if you were about to mention @bob2
          Em.run.later(
            this,
            () => {
              if (
                $preview.find('.mention.cannot-see[data-name="' + name + '"]')
                  .length > 0
              ) {
                this.sendAction("cannotSeeMention", [{ name: name }]);
                found.push(name);
              }
            },
            2000
          );
        }
      });

      this.set("warnedCannotSeeMentions", found);
    });
  },

  _resetUpload(removePlaceholder) {
    if (this._validUploads > 0) {
      this._validUploads--;
    }
    if (this._validUploads === 0) {
      this.setProperties({
        uploadProgress: 0,
        isUploading: false,
        isCancellable: false
      });
    }
    if (removePlaceholder) {
      this.appEvents.trigger(
        "composer:replace-text",
        this.get("uploadPlaceholder"),
        ""
      );
    }
  },

  _bindUploadTarget() {
    this._unbindUploadTarget(); // in case it's still bound, let's clean it up first

    this._pasted = false;

    const $element = this.$();
    const csrf = this.session.get("csrfToken");
    const uploadPlaceholder = this.get("uploadPlaceholder");

    $element.fileupload({
      url: Discourse.getURL(
        `/uploads.json?client_id=${
          this.messageBus.clientId
        }&authenticity_token=${encodeURIComponent(csrf)}`
      ),
      dataType: "json",
      pasteZone: $element
    });

    $element.on("fileuploadpaste", e => {
      this._pasted = true;

      if (!$(".d-editor-input").is(":focus")) {
        return;
      }

      const { canUpload, canPasteHtml } = clipboardData(e, true);

      if (!canUpload || canPasteHtml) {
        e.preventDefault();
      }
    });

    $element.on("fileuploadsubmit", (e, data) => {
      const isPrivateMessage = this.get("composer.privateMessage");

      data.formData = { type: "composer" };
      if (isPrivateMessage) data.formData.for_private_message = true;
      if (this._pasted) data.formData.pasted = true;

      const opts = {
        isPrivateMessage,
        allowStaffToUploadAnyFileInPm: this.siteSettings
          .allow_staff_to_upload_any_file_in_pm
      };

      const isUploading = validateUploadedFiles(data.files, opts);

      this.setProperties({ uploadProgress: 0, isUploading });

      return isUploading;
    });

    $element.on("fileuploadprogressall", (e, data) => {
      this.set(
        "uploadProgress",
        parseInt((data.loaded / data.total) * 100, 10)
      );
    });

    $element.on("fileuploadsend", (e, data) => {
      this._pasted = false;
      this._validUploads++;
      this.appEvents.trigger("composer:insert-text", uploadPlaceholder);

      if (data.xhr && data.originalFiles.length === 1) {
        this.set("isCancellable", true);
        this._xhr = data.xhr();
      }
    });

    $element.on("fileuploaddone", (e, data) => {
      let upload = data.result;

      if (!this._xhr || !this._xhr._userCancelled) {
        const markdown = getUploadMarkdown(upload);
        cacheShortUploadUrl(upload.short_url, upload.url);
        this.appEvents.trigger(
          "composer:replace-text",
          uploadPlaceholder,
          markdown
        );
        this._resetUpload(false);
      } else {
        this._resetUpload(true);
      }
    });

    $element.on("fileuploadfail", (e, data) => {
      this._resetUpload(true);

      const userCancelled = this._xhr && this._xhr._userCancelled;
      this._xhr = null;

      if (!userCancelled) {
        displayErrorForUpload(data);
      }
    });

    if (this.site.mobileView) {
      $("#reply-control .mobile-file-upload").on("click.uploader", function() {
        // redirect the click on the hidden file input
        $("#mobile-uploader").click();
      });
    }

    this._firefoxPastingHack();
  },

  // Believe it or not pasting an image in Firefox doesn't work without this code
  _firefoxPastingHack() {
    const uaMatch = navigator.userAgent.match(/Firefox\/(\d+)\.\d/);
    if (uaMatch) {
      let uaVersion = parseInt(uaMatch[1]);
      if (uaVersion < 24 || 50 <= uaVersion) {
        // The hack is no longer required in FF 50 and later.
        // See: https://bugzilla.mozilla.org/show_bug.cgi?id=906420
        return;
      }
      this.$().append(
        Ember.$(
          "<div id='contenteditable' contenteditable='true' style='height: 0; width: 0; overflow: hidden'></div>"
        )
      );
      this.$("textarea").off("keydown.contenteditable");
      this.$("textarea").on("keydown.contenteditable", event => {
        // Catch Ctrl+v / Cmd+v and hijack focus to a contenteditable div. We can't
        // use the onpaste event because for some reason the paste isn't resumed
        // after we switch focus, probably because it is being executed too late.
        if ((event.ctrlKey || event.metaKey) && event.keyCode === 86) {
          // Save the current textarea selection.
          const textarea = this.$("textarea")[0];
          const selectionStart = textarea.selectionStart;
          const selectionEnd = textarea.selectionEnd;

          // Focus the contenteditable div.
          const contentEditableDiv = this.$("#contenteditable");
          contentEditableDiv.focus();

          // The paste doesn't finish immediately and we don't have any onpaste
          // event, so wait for 100ms which _should_ be enough time.
          setTimeout(() => {
            const pastedImg = contentEditableDiv.find("img");

            if (pastedImg.length === 1) {
              pastedImg.remove();
            }

            // For restoring the selection.
            textarea.focus();
            const textareaContent = $(textarea).val(),
              startContent = textareaContent.substring(0, selectionStart),
              endContent = textareaContent.substring(selectionEnd);

            const restoreSelection = function(pastedText) {
              $(textarea).val(startContent + pastedText + endContent);
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
              const imageSrc = pastedImg.attr("src");

              if (imageSrc.match(/^data:image/)) {
                // Restore the cursor position, and remove any selected text.
                restoreSelection("");

                // Create a Blob to upload.
                const image = new Image();
                image.onload = () => {
                  // Create a new canvas.
                  const canvas = document.createElementNS(
                    "http://www.w3.org/1999/xhtml",
                    "canvas"
                  );
                  canvas.height = image.height;
                  canvas.width = image.width;
                  const ctx = canvas.getContext("2d");
                  ctx.drawImage(image, 0, 0);

                  canvas.toBlob(blob =>
                    this.$().fileupload("add", { files: blob })
                  );
                };
                image.src = imageSrc;
              } else {
                restoreSelection("<img src='" + imageSrc + "'>");
              }
            }

            contentEditableDiv.html("");
          }, 100);
        }
      });
    }
  },

  @on("willDestroyElement")
  _unbindUploadTarget() {
    this._validUploads = 0;
    $("#reply-control .mobile-file-upload").off("click.uploader");
    this.messageBus.unsubscribe("/uploads/composer");
    const $uploadTarget = this.$();
    try {
      $uploadTarget.fileupload("destroy");
    } catch (e) {
      /* wasn't initialized yet */
    }
    $uploadTarget.off();
  },

  @on("willDestroyElement")
  _composerClosed() {
    this.appEvents.trigger("composer:will-close");
    Ember.run.next(() => {
      $("#main-outlet").css("padding-bottom", 0);
      // need to wait a bit for the "slide down" transition of the composer
      Ember.run.later(() => this.appEvents.trigger("composer:closed"), 400);
    });

    if (this._enableAdvancedEditorPreviewSync())
      this._teardownInputPreviewSync();
  },

  actions: {
    importQuote(toolbarEvent) {
      this.sendAction("importQuote", toolbarEvent);
    },

    onExpandPopupMenuOptions(toolbarEvent) {
      const selected = toolbarEvent.selected;
      toolbarEvent.selectText(selected.start, selected.end - selected.start);
      this.sendAction("storeToolbarState", toolbarEvent);
    },

    togglePreview() {
      this.sendAction("togglePreview");
    },

    showUploadModal(toolbarEvent) {
      this.sendAction("showUploadSelector", toolbarEvent);
    },

    extraButtons(toolbar) {
      toolbar.addButton({
        id: "quote",
        group: "fontStyles",
        icon: "comment-o",
        sendAction: "importQuote",
        title: "composer.quote_post_title",
        unshift: true
      });

      if (this.get("allowUpload") && this.get("uploadIcon")) {
        toolbar.addButton({
          id: "upload",
          group: "insertions",
          icon: this.get("uploadIcon"),
          title: "upload",
          sendAction: "showUploadModal"
        });
      }

      toolbar.addButton({
        id: "options",
        group: "extras",
        icon: "gear",
        title: "composer.options",
        sendAction: "onExpandPopupMenuOptions",
        popupMenu: true
      });

      if (this.site.mobileView) {
        toolbar.addButton({
          id: "preview",
          group: "mobileExtras",
          icon: "television",
          title: "composer.show_preview",
          sendAction: "togglePreview"
        });
      }
    },

    previewUpdated($preview) {
      // Paint mentions
      const unseenMentions = linkSeenMentions($preview, this.siteSettings);
      if (unseenMentions.length) {
        Ember.run.debounce(
          this,
          this._renderUnseenMentions,
          $preview,
          unseenMentions,
          450
        );
      }

      this._warnMentionedGroups($preview);
      this._warnCannotSeeMention($preview);

      // Paint category hashtags
      const unseenCategoryHashtags = linkSeenCategoryHashtags($preview);
      if (unseenCategoryHashtags.length) {
        Ember.run.debounce(
          this,
          this._renderUnseenCategoryHashtags,
          $preview,
          unseenCategoryHashtags,
          450
        );
      }

      // Paint tag hashtags
      if (this.siteSettings.tagging_enabled) {
        const unseenTagHashtags = linkSeenTagHashtags($preview);
        if (unseenTagHashtags.length) {
          Ember.run.debounce(
            this,
            this._renderUnseenTagHashtags,
            $preview,
            unseenTagHashtags,
            450
          );
        }
      }

      // Paint oneboxes
      const $oneboxes = $("a.onebox", $preview);
      if (
        $oneboxes.length > 0 &&
        $oneboxes.length <= this.siteSettings.max_oneboxes_per_post
      ) {
        Ember.run.debounce(this, this._loadOneboxes, $oneboxes, 450);
      }

      // Short upload urls need resolution
      resolveAllShortUrls(ajax);

      let inline = {};
      $("a.inline-onebox-loading", $preview).each(function(index, link) {
        let $link = $(link);
        $link.removeClass("inline-onebox-loading");
        let text = $link.text();
        inline[text] = inline[text] || [];
        inline[text].push($link);
      });
      if (Object.keys(inline).length > 0) {
        Ember.run.debounce(this, this._loadInlineOneboxes, inline, 450);
      }

      if (this._enableAdvancedEditorPreviewSync()) {
        this._syncScroll(
          this._syncEditorAndPreviewScroll,
          this.$(".d-editor-input"),
          $preview
        );
      }

      this.trigger("previewRefreshed", $preview);
      this.sendAction("afterRefresh", $preview);
    }
  }
});
