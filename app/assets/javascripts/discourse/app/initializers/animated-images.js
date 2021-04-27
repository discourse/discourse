import { withPluginApi } from "discourse/lib/plugin-api";

let _gifClickHandlers = {};

export default {
  name: "animated-images-pause-on-click",

  initialize() {
    withPluginApi("0.8.7", (api) => {
      function _cleanUp() {
        Object.values(_gifClickHandlers || {}).forEach((handler) =>
          handler.removeEventListener("click", _handleClick)
        );

        _gifClickHandlers = {};
      }

      function _handleClick(event) {
        const img = event.target;
        if (img && !img.previousSibling) {
          let canvas = document.createElement("canvas");
          canvas.width = img.width;
          canvas.height = img.height;
          canvas.getContext("2d").drawImage(img, 0, 0, img.width, img.height);
          canvas.setAttribute("aria-hidden", "true");
          canvas.setAttribute("role", "presentation");

          img.parentNode.classList.add("paused-animated-image");
          img.parentNode.insertBefore(canvas, img);
        } else {
          img.previousSibling.remove();
          img.parentNode.classList.remove("paused-animated-image");
        }
      }

      function _attachCommands(post, helper) {
        if (!helper) {
          return;
        }

        let images = post.querySelectorAll("img.animated");

        images.forEach((img) => {
          if (_gifClickHandlers[img.src]) {
            _gifClickHandlers[img.src].removeEventListener(
              "click",
              _handleClick
            );

            delete _gifClickHandlers[img.src];
          }

          _gifClickHandlers[img.src] = img;
          img.addEventListener("click", _handleClick, false);
        });
      }

      api.decorateCookedElement(_attachCommands, {
        onlyStream: true,
        id: "animated-images-pause-on-click",
      });

      api.cleanupStream(_cleanUp);
    });
  },
};
