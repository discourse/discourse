import { later, schedule } from "@ember/runloop";
import I18n from "I18n";
import highlightSyntax from "discourse/lib/highlight-syntax";
import lightbox from "discourse/lib/lightbox";
import { iconHTML, iconNode } from "discourse-common/lib/icon-library";
import { setTextDirections } from "discourse/lib/text-direction";
import { nativeLazyLoading } from "discourse/lib/lazy-load-images";
import { withPluginApi } from "discourse/lib/plugin-api";
import { create } from "virtual-dom";
import showModal from "discourse/lib/show-modal";

export default {
  name: "post-decorations",
  initialize(container) {
    withPluginApi("0.1", (api) => {
      const siteSettings = container.lookup("site-settings:main");
      const session = container.lookup("session:main");
      api.decorateCookedElement(
        (elem) => {
          return highlightSyntax(elem, siteSettings, session);
        },
        {
          id: "discourse-syntax-highlighting",
        }
      );

      api.decorateCookedElement(
        (elem) => {
          return lightbox(elem, siteSettings);
        },
        { id: "discourse-lightbox" }
      );

      if (siteSettings.support_mixed_text_direction) {
        api.decorateCookedElement(setTextDirections, {
          id: "discourse-text-direction",
        });
      }

      nativeLazyLoading(api);

      api.decorateCookedElement(
        (elem) => {
          elem.querySelectorAll("audio").forEach((player) => {
            player.addEventListener("play", () => {
              const postId = parseInt(
                elem.closest("article")?.dataset.postId,
                10
              );
              if (postId) {
                api.preventCloak(postId);
              }
            });
          });
        },
        { id: "discourse-audio" }
      );

      const caps = container.lookup("capabilities:main");
      if (caps.isSafari || caps.isIOS) {
        api.decorateCookedElement(
          (elem) => {
            elem.querySelectorAll("video").forEach((video) => {
              if (video.poster && video.poster !== "" && !video.autoplay) {
                return;
              }

              const source = video.querySelector("source");
              if (source) {
                // In post-cooked.js, we create the video element in a detached DOM
                // then adopt it into to the real DOM.
                // This confuses safari, and preloading/autoplay do not happen.

                // Calling `.load()` tricks Safari into loading the video element correctly
                source.parentElement.load();
              }
            });
          },
          { id: "safari-video-poster", afterAdopt: true, onlyStream: true }
        );
      }

      const oneboxTypes = {
        amazon: "discourse-amazon",
        githubactions: "fab-github",
        githubblob: "fab-github",
        githubcommit: "fab-github",
        githubpullrequest: "fab-github",
        githubissue: "fab-github",
        githubfile: "fab-github",
        githubgist: "fab-github",
        twitterstatus: "fab-twitter",
        wikipedia: "fab-wikipedia-w",
      };

      api.decorateCookedElement(
        (elem) => {
          elem.querySelectorAll(".onebox").forEach((onebox) => {
            Object.entries(oneboxTypes).forEach(([key, value]) => {
              if (onebox.classList.contains(key)) {
                onebox
                  .querySelector(".source")
                  .insertAdjacentHTML("afterbegin", iconHTML(value));
              }
            });
          });
        },
        { id: "onebox-source-icons" }
      );

      api.decorateCookedElement(
        (element) => {
          element
            .querySelectorAll(".video-container")
            .forEach((videoContainer) => {
              const video = videoContainer.getElementsByTagName("video")[0];
              video.addEventListener("loadeddata", () => {
                later(() => {
                  if (video.videoWidth === 0 || video.videoHeight === 0) {
                    const notice = document.createElement("div");
                    notice.className = "notice";
                    notice.innerHTML =
                      iconHTML("exclamation-triangle") +
                      " " +
                      I18n.t("cannot_render_video");

                    videoContainer.appendChild(notice);
                  }
                }, 500);
              });
            });
        },
        { id: "discourse-video-codecs" }
      );

      function _createButton() {
        const openPopupBtn = document.createElement("button");
        openPopupBtn.classList.add(
          "open-popup-link",
          "btn-default",
          "btn",
          "btn-icon-text"
        );
        const expandIcon = create(
          iconNode("discourse-expand", { class: "expand-table-icon" })
        );
        const openPopupText = document.createTextNode(
          I18n.t("fullscreen_table.expand_btn")
        );
        openPopupBtn.append(expandIcon, openPopupText);
        return openPopupBtn;
      }

      function isOverflown({ clientWidth, scrollWidth }) {
        return scrollWidth > clientWidth;
      }

      function generateModal(event) {
        const table = event.target.parentNode.querySelector("table");
        const tempTable = table.cloneNode(true);

        showModal("fullscreen-table").set("tableHtml", tempTable);
      }

      function generatePopups(tables) {
        tables.forEach((table) => {
          if (!isOverflown(table.parentNode)) {
            return;
          }

          const popupBtn = _createButton();
          table.parentNode.classList.add("fullscreen-table-wrapper");
          table.parentNode.insertBefore(popupBtn, table);
          popupBtn.addEventListener("click", generateModal, false);
        });
      }

      api.decorateCookedElement(
        (post) => {
          schedule("afterRender", () => {
            const tables = post.querySelectorAll("table");
            generatePopups(tables);
          });
        },
        {
          onlyStream: true,
          id: "fullscreen-table",
        }
      );
    });
  },
};
