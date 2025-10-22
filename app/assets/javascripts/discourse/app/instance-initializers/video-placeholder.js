import { spinnerHTML } from "discourse/helpers/loading-spinner";
import { iconHTML } from "discourse/lib/icon-library";
import discourseLater from "discourse/lib/later";
import { withPluginApi } from "discourse/lib/plugin-api";
import { sanitize } from "discourse/lib/text";
import { i18n } from "discourse-i18n";

export default {
  initialize(owner) {
    withPluginApi((api) => {
      function handleVideoPlaceholderClick(helper, event) {
        const parentDiv = event.target.closest(".video-placeholder-container");
        const wrapper = parentDiv.querySelector(".video-placeholder-wrapper");
        const overlay = wrapper.querySelector(".video-placeholder-overlay");

        parentDiv.style.cursor = "";
        overlay.innerHTML = spinnerHTML;

        const videoSrc = sanitizeUrl(parentDiv.dataset.videoSrc);
        const origSrc = sanitizeUrl(parentDiv.dataset.origSrc);
        const dataOrigSrcAttr =
          origSrc !== null ? `data-orig-src="${origSrc}"` : "";

        if (videoSrc === null) {
          const existingNotice = wrapper.querySelector(".notice.error");
          if (existingNotice) {
            existingNotice.remove();
          }

          const notice = document.createElement("div");
          notice.className = "notice error";
          notice.innerHTML =
            iconHTML("triangle-exclamation") + " " + i18n("invalid_video_url");
          wrapper.appendChild(notice);
          overlay.innerHTML = iconHTML("play");

          parentDiv.style.cursor = "pointer";
          parentDiv.addEventListener(
            "click",
            (e) => handleVideoPlaceholderClick(helper, e),
            { once: true }
          );
          return;
        }

        const videoHTML = `
        <video width="100%" height="100%" preload="metadata" controls style="display:none">
          <source src="${videoSrc}" ${dataOrigSrcAttr}>
          <a href="${videoSrc}">${videoSrc}</a>
        </video>`;
        parentDiv.insertAdjacentHTML("beforeend", videoHTML);
        parentDiv.classList.add("video-container");

        const video = parentDiv.querySelector("video");

        const caps = owner.lookup("service:capabilities");
        if (caps.isSafari || caps.isIOS) {
          const source = video.querySelector("source");
          if (source) {
            // In post-cooked.js, we create the video element in a detached DOM
            // then adopt it into to the real DOM.
            // This confuses safari, and preloading/autoplay do not happen.

            // Calling `.load()` tricks Safari into loading the video element correctly
            source.parentElement.load();
          }
        }

        video.addEventListener("loadeddata", () => {
          discourseLater(() => {
            if (video.videoWidth === 0 || video.videoHeight === 0) {
              const notice = document.createElement("div");
              notice.className = "notice";
              notice.innerHTML =
                iconHTML("triangle-exclamation") +
                " " +
                i18n("cannot_render_video");

              parentDiv.appendChild(notice);
            }
          }, 500);
        });

        video.addEventListener("canplay", function () {
          if (caps.isIOS) {
            // This is needed to fix video playback on iOS.
            // Without it, videos will play, but they won't always be visible.
            discourseLater(() => {
              video.play();
            }, 100);
          } else {
            video.play();
          }

          wrapper.remove();
          video.style.display = "";
          parentDiv.classList.remove("video-placeholder-container");
          parentDiv.style.backgroundImage = "none";
        });
      }

      function applyVideoPlaceholder(post, helper) {
        if (!helper) {
          return;
        }

        const containers = post.querySelectorAll(
          ".video-placeholder-container"
        );

        containers.forEach((container) => {
          // Add video thumbnail image
          if (container.dataset.thumbnailSrc) {
            const thumbnail = new Image();
            thumbnail.onload = function () {
              container.style.backgroundImage = "url('" + thumbnail.src + "')";
            };
            thumbnail.src = container.dataset.thumbnailSrc;
          }

          const wrapper = document.createElement("div"),
            overlay = document.createElement("div");

          wrapper.classList.add("video-placeholder-wrapper");
          container.appendChild(wrapper);

          overlay.classList.add("video-placeholder-overlay");
          container.style.cursor = "pointer";
          container.addEventListener(
            "click",
            handleVideoPlaceholderClick.bind(null, helper),
            { once: true }
          );
          overlay.innerHTML = `${iconHTML("play")}`;
          wrapper.appendChild(overlay);
        });
      }

      function sanitizeUrl(url) {
        try {
          const parsedUrl = new URL(url, window.location.origin);

          if (
            ["http:", "https:"].includes(parsedUrl.protocol) ||
            url.startsWith("/")
          ) {
            const sanitized = sanitize(url);

            if (
              sanitized &&
              sanitized.trim() !== "" &&
              !sanitized.includes("&gt;") &&
              !sanitized.includes("&lt;")
            ) {
              return sanitized;
            }
          }
        } catch (e) {
          // eslint-disable-next-line no-console
          console.warn("Invalid URL encountered:", url, e.message);
        }

        return null;
      }

      api.decorateCookedElement(applyVideoPlaceholder, {
        onlyStream: true,
      });
    });
  },
};
