import { withPluginApi } from "discourse/lib/plugin-api";
import getURL from "discourse-common/lib/get-url";

export default {
  initialize() {
    withPluginApi("0.8.7", (api) => {
      function _handleEvent(event) {
        const img = event.target;
        const parentDiv = img.parentElement;

        img.style.display = "none";

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

        let images = post.querySelectorAll(".video-placeholder-container img");

        images.forEach((img) => {
          img.src = getURL("/images/video-placeholder.svg");
          img.style.cursor = "pointer";
          img.addEventListener("click", _handleEvent, false);
        });
      }

      api.decorateCookedElement(_attachCommands, {
        onlyStream: true,
      });
    });
  },
};
