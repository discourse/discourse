import { lookup } from "discourse/lib/service";
import { schedule } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Columns from "discourse/lib/columns";
import { withPluginApi } from "discourse/lib/core-api";
import highlightSyntax from "discourse/lib/highlight-syntax";
import { iconElement, iconHTML } from "discourse/lib/icon-library";
import setupImageGridCarousel from "discourse/lib/image-grid-carousel";
import { nativeLazyLoading } from "discourse/lib/lazy-load-images";
import { parseAsync } from "discourse/lib/text";
import { setTextDirections } from "discourse/lib/text-direction";
import { tokenRange } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import SiteSettingsService from "discourse/services/site-settings";
import SessionService from "discourse/services/session";
import SiteService from "discourse/services/site";
import CapabilitiesService from "discourse/services/capabilities";
import ModalService from "discourse/services/modal";

export default {
  initialize(owner) {
    withPluginApi((api) => {
      const siteSettings = lookup(owner, SiteSettingsService);
      const session = lookup(owner, SessionService);
      const site = lookup(owner, SiteService);
      const capabilities = lookup(owner, CapabilitiesService);
      const modal = lookup(owner, ModalService);

      api.decorateCookedElement((elem) => {
        return highlightSyntax(elem, siteSettings, session);
      });

      api.decorateCookedElement((elem, helper) => {
        const grids = elem.querySelectorAll(".d-image-grid");
        let needsLightboxAfterRender = false;

        if (grids.length) {
          grids.forEach((grid) => {
            if (grid.dataset.mode === "carousel") {
              if (setupImageGridCarousel(grid, helper)) {
                needsLightboxAfterRender = true;
              }
              return;
            }

            return new Columns(grid, {
              columns: site.mobileView ? 2 : 3,
            });
          });
        }

        if (needsLightboxAfterRender) {
          schedule("afterRender", () => {
            import("discourse/lib/lightbox").then(({ default: lightbox }) =>
              lightbox(elem, { post: helper.model })
            );
          });
          return;
        }

        return import("discourse/lib/lightbox").then(({ default: lightbox }) =>
          lightbox(elem, { post: helper.model })
        );
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

      function _createButton(props) {
        const openPopupBtn = document.createElement("button");
        const defaultClasses = [
          "open-popup-link",
          "btn-default",
          "btn",
          "btn-icon",
          ...(props.label ? [] : ["no-text"]),
        ];

        openPopupBtn.classList.add(...defaultClasses);

        if (props.classes) {
          openPopupBtn.classList.add(...props.classes);
        }

        if (props.title) {
          openPopupBtn.title = i18n(props.title);
        }

        if (props.label && capabilities.touch) {
          openPopupBtn.innerHTML = `
          <span class="d-button-label">
            ${i18n(props.label)}
          </div>`;
        }

        if (props.icon) {
          const icon = iconElement(props.icon.name, {
            class: props.icon?.class,
          });
          openPopupBtn.prepend(icon);
        }

        return openPopupBtn;
      }

      function isOverflown({ clientWidth, scrollWidth }) {
        return scrollWidth > clientWidth;
      }

      function generateFullScreenTableModal(event) {
        const { postId } = this;
        const table = event.currentTarget.parentElement.nextElementSibling;

        if (!table) {
          return;
        }

        modal.show(
          () => import("discourse/components/modal/fullscreen-table"),
          {
            model: {
              table,
              postId,
              displayFootnotesInline: siteSettings.display_footnotes_inline,
            },
          }
        );
      }

      async function generateSpreadsheetModal() {
        const { postId, tableIndex } = this;

        try {
          const post = await ajax(`/posts/${postId}`, { type: "GET" });
          const tokens = await parseAsync(post.raw);
          const allTables = tokenRange(tokens, "table_open", "table_close");
          const tableTokens = allTables[tableIndex];

          modal.show(
            () => import("discourse/components/modal/spreadsheet-editor"),
            {
              model: {
                post,
                tableIndex,
                tableTokens,
              },
            }
          );
        } catch (error) {
          popupAjaxError(error);
        }
      }

      function generatePopups(tables, post) {
        tables.forEach((table, index) => {
          if (
            table.parentNode.querySelector(".fullscreen-table-wrapper__buttons")
          ) {
            return;
          }

          const buttonWrapper = document.createElement("div");
          buttonWrapper.classList.add("fullscreen-table-wrapper__buttons");

          const tableEditorBtn = _createButton({
            classes: ["btn-edit-table"],
            title: "table_builder.edit.btn_edit",
            icon: {
              name: "pencil",
              class: "edit-table-icon",
            },
          });

          table.parentNode.setAttribute("data-table-index", index);
          table.parentNode.classList.add("fullscreen-table-wrapper");

          if (post.can_edit) {
            table.parentNode.classList.add("--editable");
            buttonWrapper.append(tableEditorBtn);
            tableEditorBtn.addEventListener(
              "click",
              generateSpreadsheetModal.bind({
                postId: post.id,
                tableIndex: index,
              }),
              false
            );
          }

          table.parentNode.insertBefore(buttonWrapper, table);

          if (site.mobileView || !isOverflown(table.parentNode)) {
            return;
          }

          table.parentNode.classList.add("--has-overflow");

          const expandTableBtn = _createButton({
            classes: ["btn-expand-table"],
            title: "fullscreen_table.expand_btn",
            icon: { name: "discourse-expand", class: "expand-table-icon" },
          });
          buttonWrapper.append(expandTableBtn);
          expandTableBtn.addEventListener(
            "click",
            generateFullScreenTableModal.bind({ postId: post.id }),
            false
          );
          table.parentNode.insertBefore(buttonWrapper, table);
        });
      }

      api.decorateCookedElement(
        (element, helper) => {
          schedule("afterRender", () => {
            const tables = element.querySelectorAll(".md-table table");
            generatePopups(tables, helper.model);
          });
        },
        {
          onlyStream: true,
          id: "table-wrapper",
        }
      );
    });
  },
};
