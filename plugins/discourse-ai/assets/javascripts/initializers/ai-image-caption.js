import { ajax } from "discourse/lib/ajax";
import { extractError, popupAjaxError } from "discourse/lib/ajax-error";
import { apiInitializer } from "discourse/lib/api";
import {
  getUploadMarkdown,
  IMAGE_MARKDOWN_REGEX,
  isImage,
} from "discourse/lib/uploads";
import { i18n } from "discourse-i18n";

export default apiInitializer("1.25.0", (api) => {
  const buttonAttrs = {
    label: i18n("discourse_ai.ai_helper.image_caption.button_label"),
    icon: "discourse-sparkles",
    class: "generate-caption",
  };
  const settings = api.container.lookup("service:site-settings");
  const currentUser = api.getCurrentUser();

  if (
    !settings.ai_helper_enabled_features.includes("image_caption") ||
    !currentUser?.can_use_assistant
  ) {
    return;
  }

  api.addSaveableUserOptionField("auto_image_caption");

  api.addComposerImageWrapperButton(
    buttonAttrs.label,
    buttonAttrs.class,
    buttonAttrs.icon,
    (event) => {
      const imageCaptionPopup = api.container.lookup(
        "service:imageCaptionPopup"
      );

      imageCaptionPopup.popupTrigger = event.target;

      if (
        imageCaptionPopup.popupTrigger.classList.contains("generate-caption")
      ) {
        const buttonWrapper = event.target.closest(".button-wrapper");
        const imageIndex = parseInt(
          buttonWrapper.getAttribute("data-image-index"),
          10
        );
        const imageSrc = event.target
          .closest(".image-wrapper")
          .querySelector("img")
          .getAttribute("src");

        imageCaptionPopup.toggleLoadingState(true);

        const site = api.container.lookup("service:site");
        if (!site.mobileView) {
          imageCaptionPopup.showPopup = !imageCaptionPopup.showPopup;
        }

        imageCaptionPopup._request = ajax(
          `/discourse-ai/ai-helper/caption_image`,
          {
            method: "POST",
            data: {
              image_url: imageSrc,
              image_url_type: "long_url",
            },
          }
        );

        imageCaptionPopup._request
          .then(({ caption }) => {
            imageCaptionPopup.imageSrc = imageSrc;
            imageCaptionPopup.imageIndex = imageIndex;
            imageCaptionPopup.newCaption = caption;

            if (site.mobileView) {
              // Auto-saves caption on mobile view
              imageCaptionPopup.updateCaption();
            }
          })
          .catch(popupAjaxError)
          .finally(() => {
            imageCaptionPopup.toggleLoadingState(false);
          });
      }
    }
  );

  // Checks if image is small (≤ 0.1 MP)
  function isSmallImage(width, height) {
    const megapixels = (width * height) / 1000000;
    return megapixels <= 0.1;
  }

  function needsImprovedCaption(caption) {
    return caption.length < 20 || caption.split(" ").length === 1;
  }

  function getUploadUrlFromMarkdown(markdown) {
    const regex = /\(upload:\/\/([^)]+)\)/;
    const match = markdown.match(regex);
    return match ? `upload://${match[1]}` : null;
  }

  async function fetchImageCaption(imageUrl, urlType) {
    try {
      const response = await ajax(`/discourse-ai/ai-helper/caption_image`, {
        method: "POST",
        data: {
          image_url: imageUrl,
          image_url_type: urlType,
        },
      });
      return response.caption;
    } catch (error) {
      toasts.error({
        class: "ai-image-caption-error-toast",
        duration: 3000,
        data: {
          message: extractError(error),
        },
      });
    }
  }

  const autoCaptionAllowedGroups =
    settings?.ai_auto_image_caption_allowed_groups
      .split("|")
      .map((id) => parseInt(id, 10));
  const currentUserGroups = currentUser.groups.map((g) => g.id);

  if (
    !currentUserGroups.some((groupId) =>
      autoCaptionAllowedGroups.includes(groupId)
    )
  ) {
    return;
  }

  const toasts = api.container.lookup("service:toasts");
  // Automatically caption uploaded images
  api.addComposerUploadMarkdownResolver(async (upload) => {
    const autoCaptionEnabled = currentUser.get(
      "user_option.auto_image_caption"
    );

    if (
      !autoCaptionEnabled ||
      !isImage(upload.url) ||
      !needsImprovedCaption(upload.original_filename) ||
      isSmallImage(upload.width, upload.height)
    ) {
      return getUploadMarkdown(upload);
    }

    const caption = await fetchImageCaption(upload.url, "long_url");
    if (!caption) {
      return getUploadMarkdown(upload);
    }
    return `![${caption}|${upload.thumbnail_width}x${upload.thumbnail_height}](${upload.short_url})`;
  });

  // Conditionally show dialog to auto image caption
  api.composerBeforeSave(() => {
    return new Promise((resolve, reject) => {
      const dialog = api.container.lookup("service:dialog");
      const composer = api.container.lookup("service:composer");
      const localePrefix =
        "discourse_ai.ai_helper.image_caption.automatic_caption_dialog";
      const autoCaptionEnabled = currentUser.get(
        "user_option.auto_image_caption"
      );

      const imageUploads = composer.model.reply.match(IMAGE_MARKDOWN_REGEX);
      const hasImageUploads = imageUploads?.length > 0;

      if (!hasImageUploads) {
        resolve();
      }

      const imagesToCaption = imageUploads.filter((image) => {
        const caption = image
          .substring(image.indexOf("[") + 1, image.indexOf("]"))
          .split("|")[0];
        // We don't check if the image is small to show the prompt here
        // because the width/height are the thumbnail sizes so the mp count
        // is incorrect. It doesn't matter because the auto caption won't
        // happen anyways if its small because that uses the actual upload dimensions
        return needsImprovedCaption(caption);
      });

      const needsBetterCaptions = imagesToCaption?.length > 0;

      const keyValueStore = api.container.lookup("service:key-value-store");
      const imageCaptionPopup = api.container.lookup(
        "service:imageCaptionPopup"
      );
      const autoCaptionPromptKey = "ai-auto-caption-seen";
      const seenAutoCaptionPrompt = keyValueStore.getItem(autoCaptionPromptKey);

      if (autoCaptionEnabled || !needsBetterCaptions || seenAutoCaptionPrompt) {
        return resolve();
      }

      keyValueStore.setItem(autoCaptionPromptKey, true);

      dialog.confirm({
        message: i18n(`${localePrefix}.prompt`),
        confirmButtonLabel: `${localePrefix}.confirm`,
        cancelButtonLabel: `${localePrefix}.cancel`,
        class: "ai-image-caption-prompt-dialog",

        didConfirm: async () => {
          try {
            currentUser.set("user_option.auto_image_caption", true);
            await currentUser.save(["auto_image_caption"]);

            imagesToCaption.forEach(async (imageMarkdown) => {
              const uploadUrl = getUploadUrlFromMarkdown(imageMarkdown);
              imageCaptionPopup.showAutoCaptionLoader = true;
              const caption = await fetchImageCaption(uploadUrl, "short_url");

              // Find and replace the caption in the reply
              const regex = new RegExp(
                `(!\\[)[^|]+(\\|[^\\]]+\\]\\(${uploadUrl}\\))`
              );
              const newReply = composer.model.reply.replace(
                regex,
                `$1${caption}$2`
              );
              composer.model.set("reply", newReply);
              imageCaptionPopup.showAutoCaptionLoader = false;
              resolve();
            });
          } catch (error) {
            // Reject the promise if an error occurs
            // Show an error saying unable to generate captions
            reject(error);
          }
        },
        didCancel: () => {
          // Don't enable auto captions and continue with the save
          resolve();
        },
      });
    });
  });
});
