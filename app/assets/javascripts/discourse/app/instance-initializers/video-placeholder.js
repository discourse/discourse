import { withPluginApi } from "discourse/lib/plugin-api";
import { iconHTML } from "discourse-common/lib/icon-library";

export default {
  initialize() {
    withPluginApi("0.8.7", (api) => {
      function _handleEvent(event) {
        const parentDiv = event.target;

        const wrapper = parentDiv.querySelector(".video-placeholder-wrapper");
        wrapper.style.display = "none";

        const videoHTML = `
        <video width="100%" height="100%" preload="metadata" controls>
          <source src="${parentDiv.dataset.videoSrc}" ${parentDiv.dataset.origSrc}>
          <a href="${parentDiv.dataset.videoSrc}">${parentDiv.dataset.videoSrc}</a>
        </video>`;
        parentDiv.insertAdjacentHTML("beforeend", videoHTML);
        parentDiv.classList.add("video-container");

        const video = parentDiv.querySelector("video");
        video.play();
      }

      function _attachCommands(post, helper) {
        if (!helper) {
          return;
        }

        let containers = post.querySelectorAll(".video-placeholder-container");

        containers.forEach((container) => {
          container.style.cursor = "pointer";
          container.addEventListener("click", _handleEvent, false);

          const wrapper = document.createElement("div"),
            overlay = document.createElement("div");

          container.appendChild(wrapper);
          wrapper.classList.add("video-placeholder-wrapper");

          overlay.classList.add("video-placeholder-overlay");
          overlay.innerHTML = `${iconHTML("play")}`;
          wrapper.appendChild(overlay);
        });
      }

      api.decorateCookedElement(_attachCommands, {
        onlyStream: true,
      });
    });
  },
};
