import { spinnerHTML } from "discourse/helpers/loading-spinner";
import { withPluginApi } from "discourse/lib/plugin-api";
import { iconHTML } from "discourse-common/lib/icon-library";
import discourseLater from "discourse-common/lib/later";
import { i18n } from "discourse-i18n";

export default {
  initialize(owner) {
    withPluginApi("0.8.7", (api) => {
      function handleVideoPlaceholderClick(helper, event) {
        const parentDiv = event.target.closest(".video-placeholder-container");
        const wrapper = parentDiv.querySelector(".video-placeholder-wrapper");
        const overlay = wrapper.querySelector(".video-placeholder-overlay");

        parentDiv.style.cursor = "";
        overlay.innerHTML = spinnerHTML;

        const videoHTML = `
        <video width="100%" height="100%" preload="metadata" controls style="display:none">
          <source src="${parentDiv.dataset.videoSrc}" ${parentDiv.dataset.origSrc}>
          <a href="${parentDiv.dataset.videoSrc}">${parentDiv.dataset.videoSrc}</a>
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

      api.decorateCookedElement(applyVideoPlaceholder, {
        onlyStream: true,
      });
    });
  },
};
