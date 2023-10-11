import { withPluginApi } from "discourse/lib/plugin-api";
import { iconHTML } from "discourse-common/lib/icon-library";

export default {
  initialize() {
    withPluginApi("0.8.7", (api) => {
      function handleVideoPlaceholderClick(helper, event) {
        const parentDiv = event.target.closest(".video-placeholder-container");
        const wrapper = event.target.closest(".video-placeholder-wrapper");

        const videoHTML = `
        <video width="100%" height="100%" preload="metadata" controls style="display:none">
          <source src="${parentDiv.dataset.videoSrc}" ${parentDiv.dataset.origSrc}>
          <a href="${parentDiv.dataset.videoSrc}">${parentDiv.dataset.videoSrc}</a>
        </video>`;
        parentDiv.insertAdjacentHTML("beforeend", videoHTML);
        parentDiv.classList.add("video-container");

        const video = parentDiv.querySelector("video");
        video.addEventListener("canplay", function () {
          video.play();
          wrapper.remove();
          video.style.display = "";
          parentDiv.classList.remove("video-placeholder-container");
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
          const wrapper = document.createElement("div"),
            overlay = document.createElement("div");

          wrapper.classList.add("video-placeholder-wrapper");
          container.appendChild(wrapper);

          overlay.classList.add("video-placeholder-overlay");
          overlay.style.cursor = "pointer";
          overlay.addEventListener(
            "click",
            handleVideoPlaceholderClick.bind(null, helper),
            false
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
