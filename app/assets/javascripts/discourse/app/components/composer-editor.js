import {
  authorizedExtensions,
  authorizesAllExtensions,
  authorizesOneOrMoreImageExtensions,
} from "discourse/lib/uploads";
import { alias } from "@ember/object/computed";
import { BasePlugin } from "@uppy/core";
import { resolveAllShortUrls } from "pretty-text/upload-short-url";
import {
  caretPosition,
  formatUsername,
  inCodeBlock,
  tinyAvatar,
} from "discourse/lib/utilities";
import discourseComputed, {
  bind,
  observes,
  on,
} from "discourse-common/utils/decorators";
import {
  fetchUnseenHashtags,
  linkSeenHashtags,
} from "discourse/lib/link-hashtags";
import {
  cannotSee,
  fetchUnseenMentions,
  linkSeenMentions,
} from "discourse/lib/link-mentions";
import { later, next, schedule, throttle } from "@ember/runloop";
import Component from "@ember/component";
import Composer from "discourse/models/composer";
import ComposerUploadUppy from "discourse/mixins/composer-upload-uppy";
import EmberObject from "@ember/object";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse-common/lib/debounce";
import { findRawTemplate } from "discourse-common/lib/raw-templates";
import { iconHTML } from "discourse-common/lib/icon-library";
import { isTesting } from "discourse-common/config/environment";
import { loadOneboxes } from "discourse/lib/load-oneboxes";
import putCursorAtEnd from "discourse/lib/put-cursor-at-end";
import userSearch from "discourse/lib/user-search";

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
const IMAGE_MARKDOWN_REGEX = /!\[(.*?)\|(\d{1,4}x\d{1,4})(,\s*\d{1,3}%)?(.*?)\]\((upload:\/\/.*?)\)(?!(.*`))/g;

let uploadHandlers = [];
export function addComposerUploadHandler(extensions, method) {
  uploadHandlers.push({
    extensions,
    method,
  });
}
export function cleanUpComposerUploadHandler() {
  // we cannot set this to uploadHandlers = [] because that messes with
  // the references to the original array that the component has. this only
  // really affects tests, but without doing this you could addComposerUploadHandler
  // in a beforeEach function in a test but then it's not adding to the
  // existing reference that the component has, because an earlier test ran
  // cleanUpComposerUploadHandler and lost it. setting the length to 0 empties
  // the array but keeps the reference
  uploadHandlers.length = 0;
}

let uploadPreProcessors = [];
export function addComposerUploadPreProcessor(pluginClass, optionsResolverFn) {
  if (!(pluginClass.prototype instanceof BasePlugin)) {
    throw new Error(
      "Composer upload preprocessors must inherit from the Uppy BasePlugin class."
    );
  }

  uploadPreProcessors.push({
    pluginClass,
    optionsResolverFn,
  });
}
export function cleanUpComposerUploadPreProcessor() {
  uploadPreProcessors = [];
}

let uploadMarkdownResolvers = [];
export function addComposerUploadMarkdownResolver(resolver) {
  uploadMarkdownResolvers.push(resolver);
}
export function cleanUpComposerUploadMarkdownResolver() {
  uploadMarkdownResolvers = [];
}

export default Component.extend(ComposerUploadUppy, {
  classNameBindings: ["showToolbar:toolbar-visible", ":wmd-controls"],

  editorClass: ".d-editor",
  fileUploadElementId: "file-uploader",
  mobileFileUploaderId: "mobile-file-upload",
  eventPrefix: "composer",
  uploadType: "composer",
  uppyId: "composer-editor-uppy",
  composerModel: alias("composer"),
  composerModelContentKey: "reply",
  editorInputClass: ".d-editor-input",
  shouldBuildScrollMap: true,
  scrollMap: null,
  processPreview: true,

  uploadMarkdownResolvers,
  uploadPreProcessors,
  uploadHandlers,

  @discourseComputed("composer.requiredCategoryMissing")
  replyPlaceholder(requiredCategoryMissing) {
    if (requiredCategoryMissing) {
      return "composer.reply_placeholder_choose_category";
    } else {
      const key = authorizesOneOrMoreImageExtensions(
        this.currentUser.staff,
        this.siteSettings
      )
        ? "reply_placeholder"
        : "reply_placeholder_no_images";
      return `composer.${key}`;
    }
  },

  @discourseComputed
  showLink() {
    return this.currentUser && this.currentUser.link_posting_access !== "none";
  },

  @observes("focusTarget")
  setFocus() {
    if (this.focusTarget === "editor") {
      putCursorAtEnd(this.element.querySelector("textarea"));
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
      },
    };
  },

  @bind
  _userSearchTerm(term) {
    const topicId = this.get("topic.id");
    // maybe this is a brand new topic, so grab category from composer
    const categoryId =
      this.get("topic.category_id") || this.get("composer.categoryId");

    return userSearch({
      term,
      topicId,
      categoryId,
      includeGroups: true,
    });
  },

  @discourseComputed()
  acceptsAllFormats() {
    return authorizesAllExtensions(this.currentUser.staff, this.siteSettings);
  },

  @discourseComputed()
  acceptedFormats() {
    const extensions = authorizedExtensions(
      this.currentUser.staff,
      this.siteSettings
    );

    return extensions.map((ext) => `.${ext}`).join();
  },

  @bind
  _afterMentionComplete(value) {
    this.composer.set("reply", value);

    // ensures textarea scroll position is correct
    schedule("afterRender", () => {
      const input = this.element.querySelector(".d-editor-input");
      input?.blur();
      input?.focus();
    });
  },

  @on("didInsertElement")
  _composerEditorInit() {
    const $input = $(this.element.querySelector(".d-editor-input"));

    if (this.siteSettings.enable_mentions) {
      $input.autocomplete({
        template: findRawTemplate("user-selector-autocomplete"),
        dataSource: this._userSearchTerm,
        key: "@",
        transformComplete: (v) => v.username || v.name,
        afterComplete: this._afterMentionComplete,
        triggerRule: (textarea) =>
          !inCodeBlock(textarea.value, caretPosition(textarea)),
      });
    }

    this.element
      .querySelector(".d-editor-input")
      ?.addEventListener("scroll", this._throttledSyncEditorAndPreviewScroll);

    // Focus on the body unless we have a title
    if (!this.get("composer.canEditTitle")) {
      putCursorAtEnd(this.element.querySelector(".d-editor-input"));
    }

    if (this.allowUpload) {
      this._bindUploadTarget();
      this._bindMobileUploadButton();
    }

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
      reason = I18n.t("composer.error.post_length", {
        count: minimumPostLength,
      });
      const tl = this.get("currentUser.trust_level");
      if (tl === 0 || tl === 1) {
        reason +=
          "<br/>" +
          I18n.t("composer.error.try_like", {
            heart: iconHTML("heart", {
              label: I18n.t("likes_lowercase", { count: 1 }),
            }),
          });
      }
    }

    if (reason) {
      return EmberObject.create({
        failed: true,
        reason,
        lastShownAt: lastValidatedAt,
      });
    }
  },

  _resetShouldBuildScrollMap() {
    this.set("shouldBuildScrollMap", true);
  },

  @bind
  _handleInputInteraction(event) {
    const preview = this.element.querySelector(".d-editor-preview-wrapper");

    if (!$(preview).is(":visible")) {
      return;
    }

    preview.removeEventListener("scroll", this._handleInputOrPreviewScroll);
    event.target.addEventListener("scroll", this._handleInputOrPreviewScroll);
  },

  @bind
  _handleInputOrPreviewScroll(event) {
    this._syncScroll(
      this._syncEditorAndPreviewScroll,
      $(event.target),
      $(this.element.querySelector(".d-editor-preview-wrapper"))
    );
  },

  @bind
  _handlePreviewInteraction(event) {
    this.element
      .querySelector(".d-editor-input")
      ?.removeEventListener("scroll", this._handleInputOrPreviewScroll);

    event.target?.addEventListener("scroll", this._handleInputOrPreviewScroll);
  },

  _syncScroll($callback, $input, $preview) {
    if (!this.scrollMap || this.shouldBuildScrollMap) {
      this.set("scrollMap", this._buildScrollMap($input, $preview));
      this.set("shouldBuildScrollMap", false);
    }

    throttle(this, $callback, $input, $preview, this.scrollMap, 20);
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
        "white-space": $input.css("white-space"),
      })
      .appendTo("body");

    const linesMap = [];
    let numberOfLines = 0;

    $input
      .val()
      .split("\n")
      .forEach((text) => {
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

  @bind
  _throttledSyncEditorAndPreviewScroll(event) {
    const $preview = $(this.element.querySelector(".d-editor-preview-wrapper"));

    throttle(
      this,
      this._syncEditorAndPreviewScroll,
      $(event.target),
      $preview,
      20
    );
  },

  _syncEditorAndPreviewScroll($input, $preview) {
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
  },

  _renderUnseenMentions(preview, unseen) {
    // 'Create a New Topic' scenario is not supported (per conversation with codinghorror)
    // https://meta.discourse.org/t/taking-another-1-7-release-task/51986/7
    fetchUnseenMentions(unseen, this.get("composer.topic.id")).then((r) => {
      linkSeenMentions(preview, this.siteSettings);
      this._warnMentionedGroups(preview);
      this._warnCannotSeeMention(preview);
      this._warnHereMention(r.here_count);
    });
  },

  _renderUnseenHashtags(preview) {
    const unseen = linkSeenHashtags(preview);
    if (unseen.length > 0) {
      fetchUnseenHashtags(unseen).then(() => {
        linkSeenHashtags(preview);
      });
    }
  },

  _warnMentionedGroups(preview) {
    schedule("afterRender", () => {
      let found = this.warnedGroupMentions || [];
      preview?.querySelectorAll(".mention-group.notify")?.forEach((mention) => {
        if (this._isInQuote(mention)) {
          return;
        }

        let name = mention.dataset.name;
        if (found.indexOf(name) === -1) {
          this.groupsMentioned([
            {
              name,
              user_count: mention.dataset.mentionableUserCount,
              max_mentions: mention.dataset.maxMentions,
            },
          ]);
          found.push(name);
        }
      });

      this.set("warnedGroupMentions", found);
    });
  },

  _warnCannotSeeMention(preview) {
    const composerDraftKey = this.get("composer.draftKey");

    if (composerDraftKey === Composer.NEW_PRIVATE_MESSAGE_KEY) {
      return;
    }

    schedule("afterRender", () => {
      let found = this.warnedCannotSeeMentions || [];

      preview?.querySelectorAll(".mention.cannot-see")?.forEach((mention) => {
        let name = mention.dataset.name;

        if (found.indexOf(name) === -1) {
          // add a delay to allow for typing, so you don't open the warning right away
          // previously we would warn after @bob even if you were about to mention @bob2
          later(
            this,
            () => {
              if (
                preview?.querySelectorAll(
                  `.mention.cannot-see[data-name="${name}"]`
                )?.length > 0
              ) {
                this.cannotSeeMention([{ name, reason: cannotSee[name] }]);
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

  _warnHereMention(hereCount) {
    if (!hereCount || hereCount === 0) {
      return;
    }

    later(
      this,
      () => {
        this.hereMention(hereCount);
      },
      2000
    );
  },

  @bind
  _handleImageScaleButtonClick(event) {
    if (!event.target.classList.contains("scale-btn")) {
      return;
    }

    const index = parseInt(
      event.target.closest(".button-wrapper").dataset.imageIndex,
      10
    );

    const scale = event.target.dataset.scale;
    const matchingPlaceholder = this.get("composer.reply").match(
      IMAGE_MARKDOWN_REGEX
    );

    if (matchingPlaceholder) {
      const match = matchingPlaceholder[index];

      if (match) {
        const replacement = match.replace(
          IMAGE_MARKDOWN_REGEX,
          `![$1|$2, ${scale}%$4]($5)`
        );

        this.appEvents.trigger(
          "composer:replace-text",
          matchingPlaceholder[index],
          replacement,
          { regex: IMAGE_MARKDOWN_REGEX, index }
        );
      }
    }

    event.preventDefault();
    return;
  },

  resetImageControls(buttonWrapper) {
    const imageResize = buttonWrapper.querySelector(".scale-btn-container");
    const readonlyContainer = buttonWrapper.querySelector(
      ".alt-text-readonly-container"
    );
    const editContainer = buttonWrapper.querySelector(
      ".alt-text-edit-container"
    );

    imageResize.removeAttribute("hidden");
    readonlyContainer.removeAttribute("hidden");
    buttonWrapper.removeAttribute("editing");
    editContainer.setAttribute("hidden", "true");
  },

  commitAltText(buttonWrapper) {
    const index = parseInt(buttonWrapper.getAttribute("data-image-index"), 10);
    const matchingPlaceholder = this.get("composer.reply").match(
      IMAGE_MARKDOWN_REGEX
    );
    const match = matchingPlaceholder[index];
    const input = buttonWrapper.querySelector("input.alt-text-input");
    const replacement = match.replace(
      IMAGE_MARKDOWN_REGEX,
      `![${input.value}|$2$3$4]($5)`
    );

    this.appEvents.trigger("composer:replace-text", match, replacement);

    this.resetImageControls(buttonWrapper);
  },

  @bind
  _handleAltTextInputKeypress(event) {
    if (!event.target.classList.contains("alt-text-input")) {
      return;
    }

    if (event.key === "[" || event.key === "]") {
      event.preventDefault();
    }

    if (event.key === "Enter") {
      const buttonWrapper = event.target.closest(".button-wrapper");
      this.commitAltText(buttonWrapper);
    }
  },

  @bind
  _handleAltTextEditButtonClick(event) {
    if (!event.target.classList.contains("alt-text-edit-btn")) {
      return;
    }

    const buttonWrapper = event.target.closest(".button-wrapper");
    const imageResize = buttonWrapper.querySelector(".scale-btn-container");

    const readonlyContainer = buttonWrapper.querySelector(
      ".alt-text-readonly-container"
    );
    const altText = readonlyContainer.querySelector(".alt-text");

    const editContainer = buttonWrapper.querySelector(
      ".alt-text-edit-container"
    );
    const editContainerInput = editContainer.querySelector(".alt-text-input");

    buttonWrapper.setAttribute("editing", "true");
    imageResize.setAttribute("hidden", "true");
    readonlyContainer.setAttribute("hidden", "true");
    editContainerInput.value = altText.textContent;
    editContainer.removeAttribute("hidden");
    editContainerInput.focus();
    event.preventDefault();
  },

  @bind
  _handleAltTextOkButtonClick(event) {
    if (!event.target.classList.contains("alt-text-edit-ok")) {
      return;
    }

    const buttonWrapper = event.target.closest(".button-wrapper");
    this.commitAltText(buttonWrapper);
  },

  @bind
  _handleAltTextCancelButtonClick(event) {
    if (!event.target.classList.contains("alt-text-edit-cancel")) {
      return;
    }

    const buttonWrapper = event.target.closest(".button-wrapper");
    this.resetImageControls(buttonWrapper);
  },

  _registerImageAltTextButtonClick(preview) {
    preview.addEventListener("click", this._handleAltTextEditButtonClick);
    preview.addEventListener("click", this._handleAltTextOkButtonClick);
    preview.addEventListener("click", this._handleAltTextCancelButtonClick);
    preview.addEventListener("keypress", this._handleAltTextInputKeypress);
  },

  @on("willDestroyElement")
  _composerClosed() {
    this._unbindMobileUploadButton();
    this.appEvents.trigger("composer:will-close");
    next(() => {
      // need to wait a bit for the "slide down" transition of the composer
      later(
        () => this.appEvents.trigger("composer:closed"),
        isTesting() ? 0 : 400
      );
    });

    this.element
      .querySelector(".d-editor-input")
      ?.removeEventListener(
        "scroll",
        this._throttledSyncEditorAndPreviewScroll
      );

    const preview = this.element.querySelector(".d-editor-preview-wrapper");
    preview?.removeEventListener("click", this._handleImageScaleButtonClick);
    preview?.removeEventListener("click", this._handleAltTextEditButtonClick);
    preview?.removeEventListener("click", this._handleAltTextOkButtonClick);
    preview?.removeEventListener("click", this._handleAltTextCancelButtonClick);
    preview?.removeEventListener("keypress", this._handleAltTextInputKeypress);
  },

  onExpandPopupMenuOptions(toolbarEvent) {
    const selected = toolbarEvent.selected;
    toolbarEvent.selectText(selected.start, selected.end - selected.start);
    this.storeToolbarState(toolbarEvent);
  },

  showPreview() {
    this.send("togglePreview");
  },

  _isInQuote(element) {
    let parent = element.parentElement;
    while (parent && !this._isPreviewRoot(parent)) {
      if (this._isQuote(parent)) {
        return true;
      }

      parent = parent.parentElement;
    }

    return false;
  },

  _isPreviewRoot(element) {
    return (
      element.tagName === "DIV" &&
      element.classList.contains("d-editor-preview")
    );
  },

  _isQuote(element) {
    return element.tagName === "ASIDE" && element.classList.contains("quote");
  },

  _cursorIsOnEmptyLine() {
    const textArea = this.element.querySelector(".d-editor-input");
    const selectionStart = textArea.selectionStart;
    if (selectionStart === 0) {
      return true;
    } else if (textArea.value.charAt(selectionStart - 1) === "\n") {
      return true;
    } else {
      return false;
    }
  },

  _findMatchingUploadHandler(fileName) {
    return this.uploadHandlers.find((handler) => {
      const ext = handler.extensions.join("|");
      const regex = new RegExp(`\\.(${ext})$`, "i");
      return regex.test(fileName);
    });
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
        tabindex: "0",
        id: "quote",
        group: "fontStyles",
        icon: "far-comment",
        sendAction: this.importQuote,
        title: "composer.quote_post_title",
        unshift: true,
      });

      if (this.allowUpload && this.uploadIcon && !this.site.mobileView) {
        toolbar.addButton({
          id: "upload",
          group: "insertions",
          icon: this.uploadIcon,
          title: "upload",
          sendAction: this.showUploadModal,
        });
      }

      toolbar.addButton({
        id: "options",
        group: "extras",
        icon: "cog",
        title: "composer.options",
        sendAction: this.onExpandPopupMenuOptions.bind(this),
        popupMenu: true,
      });
    },

    previewUpdated(preview) {
      // cache jquery objects for functions still using jquery
      const $preview = $(preview);

      // Paint mentions
      const unseenMentions = linkSeenMentions(preview, this.siteSettings);
      if (unseenMentions.length) {
        discourseDebounce(
          this,
          this._renderUnseenMentions,
          preview,
          unseenMentions,
          450
        );
      }

      this._warnMentionedGroups(preview);
      this._warnCannotSeeMention(preview);

      // Paint category and tag hashtags
      const unseenHashtags = linkSeenHashtags(preview);
      if (unseenHashtags.length > 0) {
        discourseDebounce(this, this._renderUnseenHashtags, preview, 450);
      }

      // Paint oneboxes
      const paintFunc = () => {
        const post = this.get("composer.post");
        let refresh = false;

        //If we are editing a post, we'll refresh its contents once.
        if (post && !post.get("refreshedPost")) {
          refresh = true;
        }

        const paintedCount = loadOneboxes(
          preview,
          ajax,
          this.get("composer.topic.id"),
          this.get("composer.category.id"),
          this.siteSettings.max_oneboxes_per_post,
          refresh
        );

        if (refresh && paintedCount > 0) {
          post.set("refreshedPost", true);
        }
      };

      discourseDebounce(this, paintFunc, 450);

      // Short upload urls need resolution
      resolveAllShortUrls(ajax, this.siteSettings, preview);

      preview.addEventListener("click", this._handleImageScaleButtonClick);
      this._registerImageAltTextButtonClick(preview);

      this.trigger("previewRefreshed", preview);
      this.afterRefresh($preview);
    },
  },
});
