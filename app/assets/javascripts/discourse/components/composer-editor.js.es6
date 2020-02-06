import { throttle } from "@ember/runloop";
import { next } from "@ember/runloop";
import { debounce } from "@ember/runloop";
import { scheduleOnce } from "@ember/runloop";
import { later } from "@ember/runloop";
import Component from "@ember/component";
import userSearch from "discourse/lib/user-search";
import discourseComputed, {
  observes,
  on
} from "discourse-common/utils/decorators";
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
import { load, LOADING_ONEBOX_CSS_CLASS } from "pretty-text/oneboxer";
import { applyInlineOneboxes } from "pretty-text/inline-oneboxer";
import { ajax } from "discourse/lib/ajax";
import EmberObject from "@ember/object";
import { findRawTemplate } from "discourse/lib/raw-templates";
import { iconHTML } from "discourse-common/lib/icon-library";
import {
  tinyAvatar,
  formatUsername,
  clipboardData,
  safariHacksDisabled,
  caretPosition,
  inCodeBlock
} from "discourse/lib/utilities";
import {
  validateUploadedFiles,
  authorizesOneOrMoreImageExtensions,
  getUploadMarkdown,
  displayErrorForUpload
} from "discourse/lib/uploads";

import {
  cacheShortUploadUrl,
  resolveAllShortUrls
} from "pretty-text/upload-short-url";
import {
  INLINE_ONEBOX_LOADING_CSS_CLASS,
  INLINE_ONEBOX_CSS_CLASS
} from "pretty-text/context/inline-onebox-css-classes";
import ENV from "discourse-common/config/environment";

const REBUILD_SCROLL_MAP_EVENTS = ["composer:resized", "composer:typed-reply"];

const uploadHandlers = [];
export function addComposerUploadHandler(extensions, method) {
  uploadHandlers.push({
    extensions,
    method
  });
}

const uploadMarkdownResolvers = [];
export function addComposerUploadMarkdownResolver(resolver) {
  uploadMarkdownResolvers.push(resolver);
}

export default Component.extend({
  classNameBindings: ["showToolbar:toolbar-visible", ":wmd-controls"],

  uploadProgress: 0,
  _xhr: null,
  shouldBuildScrollMap: true,
  scrollMap: null,
  uploadFilenamePlaceholder: null,

  @discourseComputed("uploadFilenamePlaceholder")
  uploadPlaceholder(uploadFilenamePlaceholder) {
    const clipboard = I18n.t("clipboard");
    const filename = uploadFilenamePlaceholder
      ? uploadFilenamePlaceholder
      : clipboard;
    return `[${I18n.t("uploading_filename", { filename })}]() `;
  },

  @discourseComputed("composer.requiredCategoryMissing")
  replyPlaceholder(requiredCategoryMissing) {
    if (requiredCategoryMissing) {
      return "composer.reply_placeholder_choose_category";
    } else {
      const key = authorizesOneOrMoreImageExtensions(this.currentUser.staff)
        ? "reply_placeholder"
        : "reply_placeholder_no_images";
      return `composer.${key}`;
    }
  },

  @discourseComputed
  showLink() {
    return (
      this.currentUser && this.currentUser.get("link_posting_access") !== "none"
    );
  },

  @discourseComputed("composer.requiredCategoryMissing", "composer.replyLength")
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

  @observes("focusTarget")
  setFocus() {
    if (this.focusTarget === "editor") {
      $(this.element.querySelector("textarea")).putCursorAtEnd();
    }
  },

  @discourseComputed
  markdownOptions() {
    return {
      previewing: true,

      formatUsername,

      lookupAvatarByPostNumber: (postNumber, topicId) => {
        const topic = this.topic;
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
        const topic = this.topic;
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

  userSearchTerm(term) {
    const topicId = this.get("topic.id");
    // maybe this is a brand new topic, so grab category from composer
    const categoryId =
      this.get("topic.category_id") || this.get("composer.categoryId");

    return userSearch({
      term,
      topicId,
      categoryId,
      includeMentionableGroups: true
    });
  },

  @on("didInsertElement")
  _composerEditorInit() {
    const $input = $(this.element.querySelector(".d-editor-input"));
    const $preview = $(this.element.querySelector(".d-editor-preview-wrapper"));

    if (this.siteSettings.enable_mentions) {
      $input.autocomplete({
        template: findRawTemplate("user-selector-autocomplete"),
        dataSource: term => this.userSearchTerm.call(this, term),
        key: "@",
        transformComplete: v => v.username || v.name,
        afterComplete() {
          // ensures textarea scroll position is correct
          scheduleOnce("afterRender", () => $input.blur().focus());
        },
        triggerRule: textarea =>
          !inCodeBlock(textarea.value, caretPosition(textarea))
      });
    }

    if (this._enableAdvancedEditorPreviewSync()) {
      this._initInputPreviewSync($input, $preview);
    } else {
      $input.on("scroll", () =>
        throttle(this, this._syncEditorAndPreviewScroll, $input, $preview, 20)
      );
    }

    // Focus on the body unless we have a title
    if (
      !this.get("composer.canEditTitle") &&
      (!this.capabilities.isIOS || safariHacksDisabled())
    ) {
      $(this.element.querySelector(".d-editor-input")).putCursorAtEnd();
    }

    this._bindUploadTarget();
    this.appEvents.trigger("composer:will-open");
  },

  @discourseComputed(
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
      const tl = this.get("currentUser.trust_level");
      if (tl === 0 || tl === 1) {
        reason +=
          "<br/>" +
          I18n.t("composer.error.try_like", { heart: iconHTML("heart") });
      }
    }

    if (reason) {
      return EmberObject.create({
        failed: true,
        reason,
        lastShownAt: lastValidatedAt
      });
    }
  },

  _setUploadPlaceholderSend(data) {
    const filename = this._filenamePlaceholder(data);
    this.set("uploadFilenamePlaceholder", filename);

    // when adding two separate files with the same filename search for matching
    // placeholder already existing in the editor ie [Uploading: test.png...]
    // and add order nr to the next one: [Uplodading: test.png(1)...]
    const escapedFilename = filename.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const regexString = `\\[${I18n.t("uploading_filename", {
      filename: escapedFilename + "(?:\\()?([0-9])?(?:\\))?"
    })}\\]\\(\\)`;
    const globalRegex = new RegExp(regexString, "g");
    const matchingPlaceholder = this.get("composer.reply").match(globalRegex);
    if (matchingPlaceholder) {
      // get last matching placeholder and its consecutive nr in regex
      // capturing group and apply +1 to the placeholder
      const lastMatch = matchingPlaceholder[matchingPlaceholder.length - 1];
      const regex = new RegExp(regexString);
      const orderNr = regex.exec(lastMatch)[1]
        ? parseInt(regex.exec(lastMatch)[1], 10) + 1
        : 1;
      data.orderNr = orderNr;
      const filenameWithOrderNr = `${filename}(${orderNr})`;
      this.set("uploadFilenamePlaceholder", filenameWithOrderNr);
    }
  },

  _setUploadPlaceholderDone(data) {
    const filename = this._filenamePlaceholder(data);
    const filenameWithSize = `${filename} (${data.total})`;
    this.set("uploadFilenamePlaceholder", filenameWithSize);

    if (data.orderNr) {
      const filenameWithOrderNr = `${filename}(${data.orderNr})`;
      this.set("uploadFilenamePlaceholder", filenameWithOrderNr);
    } else {
      this.set("uploadFilenamePlaceholder", filename);
    }
  },

  _filenamePlaceholder(data) {
    return data.files[0].name.replace(/\u200B-\u200D\uFEFF]/g, "");
  },

  _resetUploadFilenamePlaceholder() {
    this.set("uploadFilenamePlaceholder", null);
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

    scheduleOnce("afterRender", () => {
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
    if (!this.scrollMap || this.shouldBuildScrollMap) {
      this.set("scrollMap", this._buildScrollMap($input, $preview));
      this.set("shouldBuildScrollMap", false);
    }

    throttle(this, $callback, $input, $preview, this.scrollMap, 20);
  },

  _teardownInputPreviewSync() {
    [
      $(this.element.querySelector(".d-editor-input")),
      $(this.element.querySelector(".d-editor-preview-wrapper"))
    ].forEach($element => {
      $element.off("mouseenter touchstart");
      $element.off("scroll");
    });

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

  _loadOneboxes(oneboxes) {
    const post = this.get("composer.post");
    let refresh = false;

    // If we are editing a post, we'll refresh its contents once.
    if (post && !post.get("refreshedPost")) {
      refresh = true;
      post.set("refreshedPost", true);
    }

    Object.values(oneboxes).forEach(onebox => {
      onebox.forEach($onebox => {
        load({
          elem: $onebox,
          refresh,
          ajax,
          categoryId: this.get("composer.category.id"),
          topicId: this.get("composer.topic.id")
        });
      });
    });
  },

  _warnMentionedGroups($preview) {
    scheduleOnce("afterRender", () => {
      var found = this.warnedGroupMentions || [];
      $preview.find(".mention-group.notify").each((idx, e) => {
        const $e = $(e);
        var name = $e.data("name");
        if (found.indexOf(name) === -1) {
          this.groupsMentioned([
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

    if (composerDraftKey === Composer.NEW_PRIVATE_MESSAGE_KEY) {
      return;
    }

    scheduleOnce("afterRender", () => {
      let found = this.warnedCannotSeeMentions || [];

      $preview.find(".mention.cannot-see").each((idx, e) => {
        const $e = $(e);
        let name = $e.data("name");

        if (found.indexOf(name) === -1) {
          // add a delay to allow for typing, so you don't open the warning right away
          // previously we would warn after @bob even if you were about to mention @bob2
          later(
            this,
            () => {
              if (
                $preview.find('.mention.cannot-see[data-name="' + name + '"]')
                  .length > 0
              ) {
                this.cannotSeeMention([{ name }]);
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
    next(() => {
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
          this.uploadPlaceholder,
          ""
        );
      }
      this._resetUploadFilenamePlaceholder();
    });
  },

  _bindUploadTarget() {
    this._unbindUploadTarget(); // in case it's still bound, let's clean it up first
    this._pasted = false;

    const $element = $(this.element);

    $element.fileupload({
      url: Discourse.getURL(
        `/uploads.json?client_id=${this.messageBus.clientId}`
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
      const max = this.siteSettings.simultaneous_uploads;

      // Limit the number of simultaneous uploads
      if (max > 0 && data.files.length > max) {
        bootbox.alert(
          I18n.t("post.errors.too_many_dragged_and_dropped_files", { max })
        );
        return false;
      }

      // Look for a matching file upload handler contributed from a plugin
      const matcher = handler => {
        const ext = handler.extensions.join("|");
        const regex = new RegExp(`\\.(${ext})$`, "i");
        return regex.test(data.files[0].name);
      };

      const matchingHandler = uploadHandlers.find(matcher);
      if (data.files.length === 1 && matchingHandler) {
        if (!matchingHandler.method(data.files[0], this)) {
          return false;
        }
      }

      // If no plugin, continue as normal
      const isPrivateMessage = this.get("composer.privateMessage");

      data.formData = { type: "composer" };
      if (isPrivateMessage) data.formData.for_private_message = true;
      if (this._pasted) data.formData.pasted = true;

      const opts = {
        user: this.currentUser,
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

      this._setUploadPlaceholderSend(data);

      this.appEvents.trigger("composer:insert-text", this.uploadPlaceholder);

      if (data.xhr && data.originalFiles.length === 1) {
        this.set("isCancellable", true);
        this._xhr = data.xhr();
      }
    });

    $element.on("fileuploaddone", (e, data) => {
      let upload = data.result;
      this._setUploadPlaceholderDone(data);
      if (!this._xhr || !this._xhr._userCancelled) {
        const markdown = uploadMarkdownResolvers.reduce(
          (md, resolver) => resolver(upload) || md,
          getUploadMarkdown(upload)
        );

        cacheShortUploadUrl(upload.short_url, upload);
        this.appEvents.trigger(
          "composer:replace-text",
          this.uploadPlaceholder.trim(),
          markdown
        );
        this._resetUpload(false);
      } else {
        this._resetUpload(true);
      }
    });

    $element.on("fileuploadfail", (e, data) => {
      this._setUploadPlaceholderDone(data);
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
  },

  _registerImageScaleButtonClick($preview) {
    // original string `![image|foo=bar|690x220, 50%|bar=baz](upload://1TjaobgKObzpU7xRMw2HuUc87vO.png "image title")`
    // group 1 `image|foo=bar`
    // group 2 `690x220`
    // group 3 `, 50%`
    // group 4 '|bar=baz'
    // group 5 'upload://1TjaobgKObzpU7xRMw2HuUc87vO.png "image title"'

    // Notes:
    // Group 3 is optional. group 4 can match images with or without a markdown title.
    // All matches are whitespace tolerant as long it's still valid markdown.
    // If the image is inside a code block, we'll ignore it `(?!(.*`))`.
    const imageScaleRegex = /!\[(.*?)\|(\d{1,4}x\d{1,4})(,\s*\d{1,3}%)?(.*?)\]\((upload:\/\/.*?)\)(?!(.*`))/g;
    $preview.off("click", ".scale-btn").on("click", ".scale-btn", e => {
      const index = parseInt(
        $(e.target)
          .parent()
          .attr("data-image-index"),
        10
      );

      const scale = e.target.attributes["data-scale"].value;
      const matchingPlaceholder = this.get("composer.reply").match(
        imageScaleRegex
      );

      if (matchingPlaceholder) {
        const match = matchingPlaceholder[index];
        if (!match) {
          return;
        }

        const replacement = match.replace(
          imageScaleRegex,
          `![$1|$2, ${scale}%$4]($5)`
        );

        this.appEvents.trigger(
          "composer:replace-text",
          matchingPlaceholder[index],
          replacement,
          { regex: imageScaleRegex, index }
        );
      }
    });
  },

  @on("willDestroyElement")
  _unbindUploadTarget() {
    this._validUploads = 0;
    $("#reply-control .mobile-file-upload").off("click.uploader");
    this.messageBus.unsubscribe("/uploads/composer");
    const $uploadTarget = $(this.element);
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
    next(() => {
      // need to wait a bit for the "slide down" transition of the composer
      later(
        () => this.appEvents.trigger("composer:closed"),
        ENV.environment === "test" ? 0 : 400
      );
    });

    if (this._enableAdvancedEditorPreviewSync())
      this._teardownInputPreviewSync();
  },

  showUploadSelector(toolbarEvent) {
    this.send("showUploadSelector", toolbarEvent);
  },

  onExpandPopupMenuOptions(toolbarEvent) {
    const selected = toolbarEvent.selected;
    toolbarEvent.selectText(selected.start, selected.end - selected.start);
    this.storeToolbarState(toolbarEvent);
  },

  showPreview() {
    this.send("togglePreview");
  },

  actions: {
    importQuote(toolbarEvent) {
      this.importQuote(toolbarEvent);
    },

    onExpandPopupMenuOptions(toolbarEvent) {
      this.onExpandPopupMenuOptions(toolbarEvent);
    },

    togglePreview() {
      this.togglePreview();
    },

    extraButtons(toolbar) {
      toolbar.addButton({
        id: "quote",
        group: "fontStyles",
        icon: "far-comment",
        sendAction: this.importQuote,
        title: "composer.quote_post_title",
        unshift: true
      });

      if (this.allowUpload && this.uploadIcon && !this.site.mobileView) {
        toolbar.addButton({
          id: "upload",
          group: "insertions",
          icon: this.uploadIcon,
          title: "upload",
          sendAction: this.showUploadModal
        });
      }

      toolbar.addButton({
        id: "options",
        group: "extras",
        icon: "cog",
        title: "composer.options",
        sendAction: this.onExpandPopupMenuOptions.bind(this),
        popupMenu: true
      });
    },

    previewUpdated($preview) {
      // Paint mentions
      const unseenMentions = linkSeenMentions($preview, this.siteSettings);
      if (unseenMentions.length) {
        debounce(
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
        debounce(
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
          debounce(
            this,
            this._renderUnseenTagHashtags,
            $preview,
            unseenTagHashtags,
            450
          );
        }
      }

      // Paint oneboxes
      debounce(
        this,
        () => {
          const oneboxes = {};
          const inlineOneboxes = {};

          // Oneboxes = `a.onebox` -> `a.onebox-loading` -> `aside.onebox`
          // Inline Oneboxes = `a.inline-onebox-loading` -> `a.inline-onebox`

          let loadedOneboxes = $preview.find(
            `aside.onebox, a.${LOADING_ONEBOX_CSS_CLASS}, a.${INLINE_ONEBOX_CSS_CLASS}`
          ).length;

          $preview
            .find(`a.onebox, a.${INLINE_ONEBOX_LOADING_CSS_CLASS}`)
            .each((_, link) => {
              const $link = $(link);
              const text = $link.text();
              const isInline =
                $link.attr("class") === INLINE_ONEBOX_LOADING_CSS_CLASS;
              const m = isInline ? inlineOneboxes : oneboxes;

              if (loadedOneboxes < this.siteSettings.max_oneboxes_per_post) {
                if (m[text] === undefined) {
                  m[text] = [];
                  loadedOneboxes++;
                }
                m[text].push(link);
              } else {
                if (m[text] !== undefined) {
                  m[text].push(link);
                } else if (isInline) {
                  $link.removeClass(INLINE_ONEBOX_LOADING_CSS_CLASS);
                }
              }
            });

          if (Object.keys(oneboxes).length > 0) {
            this._loadOneboxes(oneboxes);
          }

          if (Object.keys(inlineOneboxes).length > 0) {
            this._loadInlineOneboxes(inlineOneboxes);
          }
        },
        450
      );

      // Short upload urls need resolution
      resolveAllShortUrls(ajax);

      if (this._enableAdvancedEditorPreviewSync()) {
        this._syncScroll(
          this._syncEditorAndPreviewScroll,
          $(this.element.querySelector(".d-editor-input")),
          $preview
        );
      }

      this._registerImageScaleButtonClick($preview);

      this.trigger("previewRefreshed", $preview);
      this.afterRefresh($preview);
    }
  }
});
