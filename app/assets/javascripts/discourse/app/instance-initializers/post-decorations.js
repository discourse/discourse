import { schedule } from "@ember/runloop";
import { create } from "virtual-dom";
import FullscreenTableModal from "discourse/components/modal/fullscreen-table";
import Columns from "discourse/lib/columns";
import highlightSyntax from "discourse/lib/highlight-syntax";
import { nativeLazyLoading } from "discourse/lib/lazy-load-images";
import lightbox from "discourse/lib/lightbox";
import { SELECTORS } from "discourse/lib/lightbox/constants";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setTextDirections } from "discourse/lib/text-direction";
import { iconHTML, iconNode } from "discourse-common/lib/icon-library";
import I18n from "discourse-i18n";

export default {
  initialize(owner) {
    withPluginApi("0.1", (api) => {
      const siteSettings = owner.lookup("service:site-settings");
      const session = owner.lookup("service:session");
      const site = owner.lookup("service:site");
      const modal = owner.lookup("service:modal");
      // will eventually just be called lightbox
      const lightboxService = owner.lookup("service:lightbox");
      api.decorateCookedElement((elem) => {
        return highlightSyntax(elem, siteSettings, session);
      });

      if (siteSettings.enable_experimental_lightbox) {
        api.decorateCookedElement(
          (element, helper) => {
            return helper &&
              element.querySelector(SELECTORS.DEFAULT_ITEM_SELECTOR)
              ? lightboxService.setupLightboxes({
                  container: element,
                  selector: SELECTORS.DEFAULT_ITEM_SELECTOR,
                })
              : null;
          },
          {
            onlyStream: true,
          }
        );

        api.cleanupStream(lightboxService.cleanupLightboxes);
      } else {
        api.decorateCookedElement((elem) => {
          return lightbox(elem, siteSettings);
        });
      }

      api.decorateCookedElement((elem) => {
        const grids = elem.querySelectorAll(".d-image-grid");

        if (!grids.length) {
          return;
        }

        grids.forEach((grid) => {
          return new Columns(grid, {
            columns: site.mobileView ? 2 : 3,
          });
        });
      });

      if (siteSettings.support_mixed_text_direction) {
        api.decorateCookedElement(setTextDirections, {});
      }

      nativeLazyLoading(api);

      api.decorateCookedElement((elem) => {
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
      });

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

      api.decorateCookedElement((elem) => {
        elem.querySelectorAll(".onebox").forEach((onebox) => {
          Object.entries(oneboxTypes).forEach(([key, value]) => {
            if (onebox.classList.contains(key)) {
              onebox
                .querySelector(".source")
                .insertAdjacentHTML("afterbegin", iconHTML(value));
            }
          });
        });
      });

      function _createButton() {
        const openPopupBtn = document.createElement("button");
        openPopupBtn.classList.add(
          "open-popup-link",
          "btn-default",
          "btn",
          "btn-icon",
          "btn-expand-table",
          "no-text"
        );
        const expandIcon = create(
          iconNode("discourse-expand", { class: "expand-table-icon" })
        );
        openPopupBtn.title = I18n.t("fullscreen_table.expand_btn");
        openPopupBtn.append(expandIcon);
        return openPopupBtn;
      }

      function isOverflown({ clientWidth, scrollWidth }) {
        return scrollWidth > clientWidth;
      }

      function generateModal(event) {
        const table = event.currentTarget.parentElement.nextElementSibling;
        const tempTable = table.cloneNode(true);
        modal.show(FullscreenTableModal, { model: { tableHtml: tempTable } });
      }

      function generatePopups(tables) {
        tables.forEach((table) => {
          if (!isOverflown(table.parentNode)) {
            return;
          }

          if (site.isMobileDevice) {
            return;
          }

          const popupBtn = _createButton();
          table.parentNode.classList.add("fullscreen-table-wrapper");
          // Create a button wrapper for case of multiple buttons (i.e. table builder extension)
          const buttonWrapper = document.createElement("div");
          buttonWrapper.classList.add("fullscreen-table-wrapper--buttons");
          buttonWrapper.append(popupBtn);
          popupBtn.addEventListener("click", generateModal, false);
          table.parentNode.insertBefore(buttonWrapper, table);
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
        }
      );
    });
  },
};
