import { iconHTML } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import { prefersReducedMotion } from "discourse/lib/utilities";

let _gifClickHandlers = {};

function _pauseAnimation(img, opts = {}) {
  let canvas = document.createElement("canvas");
  canvas.width = img.width;
  canvas.height = img.height;
  canvas.getContext("2d").drawImage(img, 0, 0, img.width, img.height);
  canvas.setAttribute("aria-hidden", "true");
  canvas.setAttribute("role", "presentation");

  if (opts.manualPause) {
    img.classList.add("manually-paused");
  }
  img.parentNode.classList.add("paused-animated-image");
  img.parentNode.insertBefore(canvas, img);
}

function _resumeAnimation(img) {
  if (img.previousSibling && img.previousSibling.nodeName === "CANVAS") {
    img.previousSibling.remove();
  }
  img.parentNode.classList.remove("paused-animated-image");
}

function animatedImgs() {
  return document.querySelectorAll(
    ".topic-post img.animated:not(.manually-paused)"
  );
}

export default {
  initialize() {
    withPluginApi("0.8.7", (api) => {
      function _cleanUp() {
        Object.values(_gifClickHandlers || {}).forEach((handler) => {
          handler.removeEventListener("click", _handleEvent);
          handler.removeEventListener("load", _handleEvent);
        });

        _gifClickHandlers = {};
      }

      function _handleEvent(event) {
        const img = event.target;
        if (img && !img.previousSibling) {
          _pauseAnimation(img, { manualPause: true });
        } else {
          _resumeAnimation(img);
        }
      }

      function _attachCommands(post, helper) {
        if (!helper) {
          return;
        }

        let images = post.querySelectorAll("img.animated:not(.onebox-avatar)");

        images.forEach((img) => {
          // skip for edge case of multiple animated images in same block
          if (img.parentNode.querySelectorAll("img").length > 1) {
            return;
          }

          if (_gifClickHandlers[img.src]) {
            _gifClickHandlers[img.src].removeEventListener(
              "click",
              _handleEvent
            );
            _gifClickHandlers[img.src].removeEventListener(
              "load",
              _handleEvent
            );
            delete _gifClickHandlers[img.src];
          }

          _gifClickHandlers[img.src] = img;
          img.addEventListener("click", _handleEvent, false);

          if (prefersReducedMotion()) {
            img.addEventListener("load", _handleEvent, false);
          }

          const wrapper = document.createElement("div"),
            overlay = document.createElement("div");

          img.parentNode.insertBefore(wrapper, img);
          wrapper.classList.add("pausable-animated-image");
          wrapper.appendChild(img);

          overlay.classList.add("animated-image-overlay");
          overlay.setAttribute("aria-hidden", "true");
          overlay.setAttribute("role", "presentation");
          overlay.innerHTML = `${iconHTML("pause")}${iconHTML("play")}`;
          wrapper.appendChild(overlay);
        });
      }

      api.decorateCookedElement(_attachCommands, {
        onlyStream: true,
      });

      api.cleanupStream(_cleanUp);

      // paused on load when prefers-reduced-motion is active, no need for blur/focus events
      if (!prefersReducedMotion()) {
        window.addEventListener("blur", this.blurEvent);
        window.addEventListener("focus", this.focusEvent);
      }
    });
  },

  blurEvent() {
    animatedImgs().forEach((img) => {
      if (
        img.parentNode.querySelectorAll("img").length === 1 &&
        !img.previousSibling
      ) {
        _pauseAnimation(img);
      }
    });
  },

  focusEvent() {
    animatedImgs().forEach((img) => {
      if (
        img.parentNode.querySelectorAll("img").length === 1 &&
        img.previousSibling
      ) {
        _resumeAnimation(img);
      }
    });
  },

  teardown() {
    window.removeEventListener("blur", this.blurEvent);
    window.removeEventListener("focus", this.focusEvent);
  },
};
