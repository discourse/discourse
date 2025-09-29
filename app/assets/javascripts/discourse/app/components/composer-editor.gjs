/* eslint-disable ember/no-classic-components */
import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { hash } from "@ember/helper";
import EmberObject, { action, computed } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { schedule, throttle } from "@ember/runloop";
import { service } from "@ember/service";
import { classNameBindings } from "@ember-decorators/component";
import { observes, on } from "@ember-decorators/object";
import { BasePlugin } from "@uppy/core";
import $ from "jquery";
import { resolveAllShortUrls } from "pretty-text/upload-short-url";
import { gt } from "truth-helpers";
import DEditor from "discourse/components/d-editor";
import DEditorPreview from "discourse/components/d-editor-preview";
import Wrapper from "discourse/components/form-template-field/wrapper";
import PickFilesButton from "discourse/components/pick-files-button";
import PostTranslationEditor from "discourse/components/post-translation-editor";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { tinyAvatar } from "discourse/lib/avatar-utils";
import { setupComposerPosition } from "discourse/lib/composer/composer-position";
import discourseComputed, { bind, debounce } from "discourse/lib/decorators";
import prepareFormTemplateData from "discourse/lib/form-template-validation";
import {
  fetchUnseenHashtagsInContext,
  linkSeenHashtagsInContext,
} from "discourse/lib/hashtag-decorator";
import { iconHTML } from "discourse/lib/icon-library";
import discourseLater from "discourse/lib/later";
import {
  fetchUnseenMentions,
  linkSeenMentions,
} from "discourse/lib/link-mentions";
import { loadOneboxes } from "discourse/lib/load-oneboxes";
import { generateCookFunction } from "discourse/lib/text";
import { applyValueTransformer } from "discourse/lib/transformer";
import {
  authorizesOneOrMoreImageExtensions,
  IMAGE_MARKDOWN_REGEX,
} from "discourse/lib/uploads";
import UppyComposerUpload from "discourse/lib/uppy/composer-upload";
import { formatUsername } from "discourse/lib/utilities";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";
import FormTemplateChooser from "select-kit/components/form-template-chooser";

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

let apiImageWrapperBtnEvents = [];
export function addApiImageWrapperButtonClickEvent(fn) {
  apiImageWrapperBtnEvents.push(fn);
}

const DEBOUNCE_FETCH_MS = 450;
const DEBOUNCE_JIT_MS = 2000;

@classNameBindings("composer.showToolbar:toolbar-visible", ":wmd-controls")
export default class ComposerEditor extends Component {
  @service composer;
  @service siteSettings;
  @service currentUser;

  @tracked preview;

  composerEventPrefix = "composer";
  shouldBuildScrollMap = true;
  scrollMap = null;

  fileUploadElementId = "file-uploader";

  init() {
    super.init(...arguments);
    this.warnedCannotSeeMentions = [];
    this.warnedGroupMentions = [];

    this.uppyComposerUpload = new UppyComposerUpload(getOwner(this), {
      composerEventPrefix: this.composerEventPrefix,
      composerModel: this.composer.model,
      uploadMarkdownResolvers,
      uploadPreProcessors,
      uploadHandlers,
      fileUploadElementId: this.fileUploadElementId,
    });
  }

  get topic() {
    return this.composer.get("model.topic");
  }

  @discourseComputed("composer.model.requiredCategoryMissing")
  replyPlaceholder(requiredCategoryMissing) {
    let placeholder = "composer.reply_placeholder_choose_category";

    if (!requiredCategoryMissing) {
      const allowImages = authorizesOneOrMoreImageExtensions(
        this.currentUser.staff,
        this.siteSettings
      );

      let key;
      if (this.siteSettings.rich_editor && this.currentUser.useRichEditor) {
        key = allowImages
          ? "reply_placeholder_rte"
          : "reply_placeholder_rte_no_images";
      } else {
        key = allowImages ? "reply_placeholder" : "reply_placeholder_no_images";
      }

      placeholder = `composer.${key}`;
    }

    return applyValueTransformer(
      "composer-editor-reply-placeholder",
      placeholder,
      { model: this.composer }
    );
  }

  @discourseComputed
  showLink() {
    return this.currentUser && this.currentUser.link_posting_access !== "none";
  }

  @observes("composer.focusTarget")
  setFocus() {
    if (this.composer.focusTarget === "editor") {
      this.textManipulation.putCursorAtEnd();
    }
  }

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
          const quotedPost = posts.find((p) => p.post_number === postNumber);
          if (quotedPost) {
            const avatarTemplate = applyValueTransformer(
              "composer-editor-quoted-post-avatar-template",
              quotedPost.get("avatar_template"),
              { post: quotedPost }
            );
            return tinyAvatar(avatarTemplate);
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
          const quotedPost = posts.find((p) => p.post_number === postNumber);
          if (quotedPost) {
            return quotedPost.primary_group_name;
          }
        }
      },

      hashtagTypesInPriorityOrder:
        this.site.hashtag_configurations["topic-composer"],
      hashtagIcons: this.site.hashtag_icons,
    };
  }

  @on("didInsertElement")
  _composerEditorInit() {
    this.appEvents.trigger(`${this.composerEventPrefix}:will-open`);
  }

  @on("willDestroyElement")
  _composerClosed() {
    this.appEvents.trigger(`${this.composerEventPrefix}:will-close`);

    // need to wait a bit for the "slide down" transition of the composer
    discourseLater(
      () => this.appEvents.trigger(`${this.composerEventPrefix}:closed`),
      400
    );
  }

  @action
  _composerEditorInitPreview(elem) {
    const preview = elem.querySelector(".d-editor-preview-wrapper");
    this._registerImageAltTextButtonClick(preview);
    this._editorInitPreview = true;
  }

  @action
  _composerEditorDestroyPreview(elem) {
    const preview = elem.querySelector(".d-editor-preview-wrapper");

    if (preview) {
      preview.removeEventListener(
        "click",
        this._handleAltTextCancelButtonClick
      );
      preview.removeEventListener("click", this._handleAltTextEditButtonClick);
      preview.removeEventListener("click", this._handleAltTextOkButtonClick);
      preview.removeEventListener("click", this._handleImageDeleteButtonClick);
      preview.removeEventListener("click", this._handleImageGridButtonClick);
      preview.removeEventListener("click", this._handleImageScaleButtonClick);
      preview.removeEventListener("keypress", this._handleAltTextInputKeypress);

      apiImageWrapperBtnEvents.forEach((fn) =>
        preview.removeEventListener("click", fn)
      );
    }
  }

  @action
  _composerEditorInitEditor(elem) {
    if (this.composer.allowUpload) {
      this.uppyComposerUpload.setup(elem);
    }
  }

  @action
  _composerEditorDestroyEditor(elem) {
    if (this.composer.allowUpload && this._cleanupComposerUploadElement) {
      this.uppyComposerUpload.teardown(elem);
    }
  }

  /**
   * Sets up the editor with the given text manipulation instance
   *
   * @param {TextManipulation} textManipulation The text manipulation instance
   * @returns {(() => void)} destructor function
   */
  @bind
  setupEditor(textManipulation) {
    this.textManipulation = textManipulation;
    this.uppyComposerUpload.placeholderHandler = textManipulation.placeholder;

    const input = this.element.querySelector(".d-editor-input");

    input.addEventListener("scroll", this._throttledSyncEditorAndPreviewScroll);

    this.composer.set("allowPreview", this.textManipulation.allowPreview);

    if (
      // Focus on the editor unless we have a title
      !this.get("composer.model.canEditTitle") ||
      // Or focus is in the body (e.g. when the editor is destroyed)
      document.activeElement.tagName === "BODY"
    ) {
      this.textManipulation.putCursorAtEnd();
    }

    const destroyComposerPosition = setupComposerPosition(input);

    return () => {
      destroyComposerPosition();

      input.removeEventListener(
        "scroll",
        this._throttledSyncEditorAndPreviewScroll
      );
    };
  }

  @discourseComputed(
    "composer.model.reply",
    "composer.model.replyLength",
    "composer.model.missingReplyCharacters",
    "composer.model.minimumPostLength",
    "composer.lastValidatedAt"
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
      reason = i18n("composer.error.post_missing");
    } else if (missingReplyCharacters > 0) {
      reason = i18n("composer.error.post_length", {
        count: minimumPostLength,
      });
      const tl = this.get("currentUser.trust_level");
      if ((tl === 0 || tl === 1) && !this._isNewTopic) {
        reason +=
          "<br/>" +
          i18n("composer.error.try_like", {
            heart: iconHTML("heart", {
              label: i18n("likes_lowercase", { count: 1 }),
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
  }

  @computed("composer.{creatingTopic,editingFirstPost,creatingSharedDraft}")
  get _isNewTopic() {
    return (
      this.composer.model.creatingTopic ||
      this.composer.model.editingFirstPost ||
      this.composer.model.creatingSharedDraft
    );
  }

  _resetShouldBuildScrollMap() {
    this.set("shouldBuildScrollMap", true);
  }

  @bind
  _handleInputInteraction(event) {
    const preview = this.element.querySelector(".d-editor-preview-wrapper");

    if (!$(preview).is(":visible")) {
      return;
    }

    preview.removeEventListener("scroll", this._handleInputOrPreviewScroll);
    event.target.addEventListener("scroll", this._handleInputOrPreviewScroll);
  }

  @bind
  _handleInputOrPreviewScroll(event) {
    this._syncScroll(
      this._syncEditorAndPreviewScroll,
      $(event.target),
      $(this.element.querySelector(".d-editor-preview-wrapper"))
    );
  }

  @bind
  _handlePreviewInteraction(event) {
    this.element
      .querySelector(".d-editor-input")
      ?.removeEventListener("scroll", this._handleInputOrPreviewScroll);

    event.target?.addEventListener("scroll", this._handleInputOrPreviewScroll);
  }

  _syncScroll($callback, $input, $preview) {
    if (!this.scrollMap || this.shouldBuildScrollMap) {
      this.set("scrollMap", this._buildScrollMap($input, $preview));
      this.set("shouldBuildScrollMap", false);
    }

    throttle(this, $callback, $input, $preview, this.scrollMap, 20);
  }

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
  }

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
  }

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
  }

  _renderMentions(preview) {
    const unseen = linkSeenMentions(preview, this.siteSettings);
    if (unseen.length > 0) {
      this._renderUnseenMentions(preview, unseen);
    } else {
      this._warnMentionedGroups(preview);
      this._warnCannotSeeMention(preview);
    }
  }

  @debounce(DEBOUNCE_FETCH_MS)
  _renderUnseenMentions(preview, unseen) {
    fetchUnseenMentions({
      names: unseen,
      topicId: this.get("composer.model.topic.id"),
      allowedNames: this.get("composer.model.targetRecipients")?.split(","),
    }).then((response) => {
      linkSeenMentions(preview, this.siteSettings);
      this._warnMentionedGroups(preview);
      this._warnCannotSeeMention(preview);
      this._warnHereMention(response.here_count);
    });
  }

  _renderHashtags(preview) {
    const context = this.site.hashtag_configurations["topic-composer"];
    const unseen = linkSeenHashtagsInContext(context, preview);
    if (unseen.length > 0) {
      this._renderUnseenHashtags(preview, unseen, context);
    }
  }

  @debounce(DEBOUNCE_FETCH_MS)
  _renderUnseenHashtags(preview, unseen, context) {
    fetchUnseenHashtagsInContext(context, unseen).then(() =>
      linkSeenHashtagsInContext(context, preview)
    );
  }

  @debounce(DEBOUNCE_FETCH_MS)
  _refreshOneboxes(preview) {
    const post = this.get("composer.post");
    // If we are editing a post, we'll refresh its contents once.
    const refresh = post && !post.get("refreshedPost");

    const loaded = loadOneboxes(
      preview,
      ajax,
      this.get("composer.topic.id"),
      this.get("composer.category.id"),
      this.siteSettings.max_oneboxes_per_post,
      refresh
    );

    if (refresh && loaded > 0) {
      post.set("refreshedPost", true);
    }
  }

  _expandShortUrls(preview) {
    resolveAllShortUrls(ajax, this.siteSettings, preview);
  }

  _decorateCookedElement(preview, helper) {
    this.appEvents.trigger(
      "decorate-non-stream-cooked-element",
      preview,
      helper
    );
  }

  @debounce(DEBOUNCE_JIT_MS)
  _warnMentionedGroups(preview) {
    schedule("afterRender", () => {
      preview
        .querySelectorAll(".mention-group[data-mentionable-user-count]")
        .forEach((mention) => {
          const { name } = mention.dataset;
          if (
            this.warnedGroupMentions.includes(name) ||
            this._isInQuote(mention)
          ) {
            return;
          }

          this.warnedGroupMentions.push(name);
          this.composer.groupsMentioned({
            name,
            userCount: mention.dataset.mentionableUserCount,
            maxMentions: mention.dataset.maxMentions,
          });
        });
    });
  }

  // add a delay to allow for typing, so you don't open the warning right away
  // previously we would warn after @bob even if you were about to mention @bob2
  @debounce(DEBOUNCE_JIT_MS)
  _warnCannotSeeMention(preview) {
    if (this.composer.model?.draftKey === Composer.NEW_PRIVATE_MESSAGE_KEY) {
      return;
    }

    preview.querySelectorAll(".mention[data-reason]").forEach((mention) => {
      const { name } = mention.dataset;
      if (this.warnedCannotSeeMentions.includes(name)) {
        return;
      }

      this.warnedCannotSeeMentions.push(name);
      this.composer.cannotSeeMention({
        name,
        reason: mention.dataset.reason,
      });
    });

    preview
      .querySelectorAll(".mention-group[data-reason]")
      .forEach((mention) => {
        const { name } = mention.dataset;
        if (this.warnedCannotSeeMentions.includes(name)) {
          return;
        }

        this.warnedCannotSeeMentions.push(name);
        this.composer.cannotSeeMention({
          name,
          reason: mention.dataset.reason,
          notifiedCount: mention.dataset.notifiedUserCount,
          isGroup: true,
        });
      });
  }

  _warnHereMention(hereCount) {
    if (!hereCount || hereCount === 0) {
      return;
    }

    this.composer.hereMention(hereCount);
  }

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
    const matchingPlaceholder = this.get("composer.model.reply").match(
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
          `${this.composerEventPrefix}:replace-text`,
          matchingPlaceholder[index],
          replacement,
          { regex: IMAGE_MARKDOWN_REGEX, index }
        );
      }
    }

    event.preventDefault();
    return;
  }

  resetImageControls(buttonWrapper) {
    const imageResize = buttonWrapper.querySelector(".scale-btn-container");
    const imageDelete = buttonWrapper.querySelector(".delete-image-button");

    const readonlyContainer = buttonWrapper.querySelector(
      ".alt-text-readonly-container"
    );
    const editContainer = buttonWrapper.querySelector(
      ".alt-text-edit-container"
    );

    imageResize.removeAttribute("hidden");
    imageDelete.removeAttribute("hidden");

    readonlyContainer.removeAttribute("hidden");
    buttonWrapper.removeAttribute("editing");
    editContainer.setAttribute("hidden", "true");
  }

  commitAltText(buttonWrapper) {
    const index = parseInt(buttonWrapper.getAttribute("data-image-index"), 10);
    const matchingPlaceholder = this.get("composer.model.reply").match(
      IMAGE_MARKDOWN_REGEX
    );
    const match = matchingPlaceholder[index];
    const input = buttonWrapper.querySelector("input.alt-text-input");
    const replacement = match.replace(
      IMAGE_MARKDOWN_REGEX,
      `![${input.value}|$2$3$4]($5)`
    );

    this.appEvents.trigger(
      `${this.composerEventPrefix}:replace-text`,
      match,
      replacement
    );

    this.resetImageControls(buttonWrapper);
  }

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
  }

  @bind
  _handleAltTextEditButtonClick(event) {
    if (!event.target.classList.contains("alt-text-edit-btn")) {
      return;
    }

    const buttonWrapper = event.target.closest(".button-wrapper");
    const imageResize = buttonWrapper.querySelector(".scale-btn-container");
    const imageDelete = buttonWrapper.querySelector(".delete-image-button");

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
    imageDelete.setAttribute("hidden", "true");
    readonlyContainer.setAttribute("hidden", "true");
    editContainerInput.value = altText.textContent;
    editContainer.removeAttribute("hidden");
    editContainerInput.focus();
    event.preventDefault();
  }

  @bind
  _handleAltTextOkButtonClick(event) {
    if (!event.target.classList.contains("alt-text-edit-ok")) {
      return;
    }

    const buttonWrapper = event.target.closest(".button-wrapper");
    this.commitAltText(buttonWrapper);
  }

  @bind
  _handleAltTextCancelButtonClick(event) {
    if (!event.target.classList.contains("alt-text-edit-cancel")) {
      return;
    }

    const buttonWrapper = event.target.closest(".button-wrapper");
    this.resetImageControls(buttonWrapper);
  }

  @bind
  _handleImageDeleteButtonClick(event) {
    if (!event.target.classList.contains("delete-image-button")) {
      return;
    }
    const index = parseInt(
      event.target.closest(".button-wrapper").dataset.imageIndex,
      10
    );
    const matchingPlaceholder = this.get("composer.model.reply").match(
      IMAGE_MARKDOWN_REGEX
    );
    this.appEvents.trigger(
      `${this.composerEventPrefix}:replace-text`,
      matchingPlaceholder[index],
      "",
      { regex: IMAGE_MARKDOWN_REGEX, index }
    );
  }

  @bind
  _handleImageGridButtonClick(event) {
    if (!event.target.classList.contains("wrap-image-grid-button")) {
      return;
    }

    const index = parseInt(
      event.target.closest(".button-wrapper").dataset.imageIndex,
      10
    );
    const reply = this.get("composer.model.reply");
    const matches = reply.match(IMAGE_MARKDOWN_REGEX);
    const closingIndex =
      index + parseInt(event.target.dataset.imageCount, 10) - 1;

    const textArea = this.element.querySelector(".d-editor-input");
    textArea.selectionStart = reply.indexOf(matches[index]);
    textArea.selectionEnd =
      reply.indexOf(matches[closingIndex]) + matches[closingIndex].length;

    this.appEvents.trigger(
      `${this.composerEventPrefix}:apply-surround`,
      "[grid]",
      "[/grid]",
      "grid_surround",
      { useBlockMode: true }
    );
  }

  _registerImageAltTextButtonClick(preview) {
    if (!preview) {
      return;
    }

    preview.addEventListener("click", this._handleAltTextCancelButtonClick);
    preview.addEventListener("click", this._handleAltTextEditButtonClick);
    preview.addEventListener("click", this._handleAltTextOkButtonClick);
    preview.addEventListener("click", this._handleImageDeleteButtonClick);
    preview.addEventListener("click", this._handleImageGridButtonClick);
    preview.addEventListener("click", this._handleImageScaleButtonClick);
    preview.addEventListener("keypress", this._handleAltTextInputKeypress);

    apiImageWrapperBtnEvents.forEach((fn) =>
      preview.addEventListener("click", fn)
    );
  }

  @action
  onExpandPopupMenuOptions(toolbarEvent) {
    const selected = toolbarEvent.selected;
    toolbarEvent.selectText(selected.start, selected.end - selected.start);
    this.composer.storeToolbarState(toolbarEvent);

    window.getSelection().removeAllRanges();
  }

  showPreview() {
    this.composer.togglePreview();
  }

  _isInQuote(element) {
    let parent = element.parentElement;
    while (parent && !this._isPreviewRoot(parent)) {
      if (this._isQuote(parent)) {
        return true;
      }

      parent = parent.parentElement;
    }

    return false;
  }

  _isPreviewRoot(element) {
    return (
      element.tagName === "DIV" &&
      element.classList.contains("d-editor-preview")
    );
  }

  _isQuote(element) {
    return element.tagName === "ASIDE" && element.classList.contains("quote");
  }

  @action
  extraButtons(toolbar) {
    if (
      this.composer.allowUpload &&
      this.composer.uploadIcon &&
      this.site.desktopView
    ) {
      toolbar.addButton({
        id: "upload",
        group: "insertions",
        icon: this.composer.uploadIcon,
        title: "upload",
        sendAction: this.showUploadModal,
      });
    }

    toolbar.addButton({
      id: "options",
      group: "extras",
      icon: "circle-plus",
      title: "composer.options",
      sendAction: this.onExpandPopupMenuOptions.bind(this),
      popupMenu: {
        options: () => this.composer.popupMenuOptions,
        action: this.composer.onPopupMenuAction,
      },
    });
  }

  @action
  previewUpdated(preview, helper) {
    this._renderMentions(preview);
    this._renderHashtags(preview);
    this._refreshOneboxes(preview);
    this._expandShortUrls(preview);

    this._decorateCookedElement(preview, helper);

    this.composer.afterRefresh(preview);
  }

  @computed("composer.formTemplateIds")
  get selectedFormTemplateId() {
    if (this._selectedFormTemplateId) {
      return this._selectedFormTemplateId;
    }

    return (
      this.composer.model.formTemplateId || this.composer.formTemplateIds?.[0]
    );
  }

  set selectedFormTemplateId(value) {
    this._selectedFormTemplateId = value;
  }

  get showTranslationEditor() {
    if (
      !this.siteSettings.content_localization_enabled ||
      !this.currentUser.can_localize_content
    ) {
      return false;
    }

    if (this.composer.model?.action === Composer.ADD_TRANSLATION) {
      return true;
    }

    return false;
  }

  @action
  async updateFormPreview() {
    const formTemplateData = prepareFormTemplateData(
      document.querySelector("#form-template-form"),
      this.composer.selectedFormTemplate,
      false
    );

    this.preview = await this.cachedCookAsync(
      formTemplateData,
      this.markdownOptions
    );
  }

  async cachedCookAsync(text, options) {
    this._cachedCookFunction ||= await generateCookFunction(options || {});
    return await this._cachedCookFunction(text);
  }

  @action
  updateSelectedFormTemplateId(formTemplateId) {
    this.selectedFormTemplateId = formTemplateId;
  }

  @discourseComputed(
    "composer.formTemplateIds",
    "composer.model.replyingToTopic",
    "composer.model.editingPost"
  )
  showFormTemplateForm(formTemplateIds, replyingToTopic, editingPost) {
    return formTemplateIds?.length > 0 && !replyingToTopic && !editingPost;
  }

  @action
  showUploadModal() {
    document.getElementById(this.fileUploadElementId).click();
  }

  <template>
    {{#if this.showFormTemplateForm}}
      <div class="d-editor">
        <div class="d-editor-textarea-column">
          {{yield}}

          {{#if (gt this.composer.formTemplateIds.length 1)}}
            <FormTemplateChooser
              @filteredIds={{this.composer.formTemplateIds}}
              @value={{this.selectedFormTemplateId}}
              @onChange={{this.updateSelectedFormTemplateId}}
              @options={{hash maximum=1}}
              class="composer-select-form-template"
            />
          {{/if}}
          <form id="form-template-form">
            <Wrapper
              @id={{this.selectedFormTemplateId}}
              @initialValues={{this.composer.formTemplateInitialValues}}
              @onSelectFormTemplate={{this.composer.onSelectFormTemplate}}
              @onChange={{this.updateFormPreview}}
            />
          </form>
        </div>
        {{#if this.siteSettings.show_preview_for_form_templates}}
          <DEditorPreview
            @preview={{this.preview}}
            @forcePreview={{this.forcePreview}}
            @onPreviewUpdated={{this.previewUpdated}}
            @outletArgs={{this.outletArgs}}
            {{didInsert this._composerEditorInitPreview}}
            {{willDestroy this._composerEditorDestroyPreview}}
          />
        {{/if}}
      </div>
    {{else if this.showTranslationEditor}}
      <PostTranslationEditor
        @setupEditor={{this.setupEditor}}
        {{didInsert this._composerEditorInitEditor}}
        {{willDestroy this._composerEditorDestroyEditor}}
        {{didInsert this._composerEditorInitPreview}}
        {{willDestroy this._composerEditorDestroyPreview}}
      />
    {{else}}
      <DEditor
        @value={{this.composer.model.reply}}
        @placeholder={{this.replyPlaceholder}}
        @previewUpdated={{this.previewUpdated}}
        @markdownOptions={{this.markdownOptions}}
        @extraButtons={{this.extraButtons}}
        @processPreview={{this.composer.isPreviewVisible}}
        @validation={{this.validation}}
        @loading={{this.composer.loading}}
        @forcePreview={{this.forcePreview}}
        @showLink={{this.showLink}}
        @composerEvents={{true}}
        @onPopupMenuAction={{this.composer.onPopupMenuAction}}
        @popupMenuOptions={{this.composer.popupMenuOptions}}
        @disabled={{this.composer.disableTextarea}}
        @outletArgs={{lazyHash
          composer=this.composer.model
          editorType="composer"
        }}
        @topicId={{this.composer.model.topic.id}}
        @categoryId={{this.composer.model.category.id}}
        @replyingToUserId={{this.composer.replyingToUserId}}
        @onSetup={{this.setupEditor}}
        @disableSubmit={{this.composer.disableSubmit}}
        {{didInsert this._composerEditorInitEditor}}
        {{willDestroy this._composerEditorDestroyEditor}}
        {{didInsert this._composerEditorInitPreview}}
        {{willDestroy this._composerEditorDestroyPreview}}
      >
        {{yield}}
      </DEditor>
    {{/if}}

    {{#if this.composer.allowUpload}}
      <PickFilesButton
        @fileInputId={{this.fileUploadElementId}}
        @allowMultiple={{true}}
        name="file-uploader"
      />
    {{/if}}
  </template>
}
