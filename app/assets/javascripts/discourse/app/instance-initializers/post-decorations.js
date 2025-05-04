import { schedule } from "@ember/runloop";
import { create } from "virtual-dom";
import FullscreenTableModal from "discourse/components/modal/fullscreen-table";
import SpreadsheetEditor from "discourse/components/modal/spreadsheet-editor";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Columns from "discourse/lib/columns";
import highlightSyntax from "discourse/lib/highlight-syntax";
import { iconHTML, iconNode } from "discourse/lib/icon-library";
import { nativeLazyLoading } from "discourse/lib/lazy-load-images";
import lightbox from "discourse/lib/lightbox";
import { withPluginApi } from "discourse/lib/plugin-api";
import { parseAsync } from "discourse/lib/text";
import { setTextDirections } from "discourse/lib/text-direction";
import { tokenRange } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default {
  initialize(owner) {
    withPluginApi("0.1", (api) => {
      const siteSettings = owner.lookup("service:site-settings");
      const session = owner.lookup("service:session");
      const site = owner.lookup("service:site");
      const capabilities = owner.lookup("service:capabilities");
      const modal = owner.lookup("service:modal");
      // will eventually just be called lightbox
      api.decorateCookedElement((elem) => {
        return highlightSyntax(elem, siteSettings, session);
      });

      api.decorateCookedElement((elem) => {
        return lightbox(elem, siteSettings);
      });

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
          const icon = create(
            iconNode(props.icon.name, { class: props.icon?.class })
          );
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
        const tempTable = table.cloneNode(true);
        const cookedWrapper = document.createElement("div");
        cookedWrapper.classList.add("cooked");
        if (siteSettings.display_footnotes_inline) {
          cookedWrapper.classList.add("inline-footnotes");
        }
        cookedWrapper.dataset.refPostId = postId;
        cookedWrapper.appendChild(tempTable);
        modal.show(FullscreenTableModal, {
          model: { tableHtml: cookedWrapper },
        });
      }

      async function generateSpreadsheetModal() {
        const { postId, tableIndex } = this;

        try {
          const post = await ajax(`/posts/${postId}`, { type: "GET" });
          const tokens = await parseAsync(post.raw);
          const allTables = tokenRange(tokens, "table_open", "table_close");
          const tableTokens = allTables[tableIndex];

          modal.show(SpreadsheetEditor, {
            model: {
              post,
              tableIndex,
              tableTokens,
            },
          });
        } catch (error) {
          popupAjaxError(error);
        }
      }

      function generatePopups(tables, post) {
        tables.forEach((table, index) => {
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

          // TODO (glimmer-post-stream) in the Glimmer post stream we can check for post.can_edit instead
          if (post.canEdit) {
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

          if (!isOverflown(table.parentNode)) {
            return;
          }

          if (site.isMobileDevice) {
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

      function cleanupPopupBtns() {
        const editTableBtn = document.querySelector(
          ".open-popup-link.btn-edit-table"
        );
        const expandTableBtn = document.querySelector(
          ".open-popup-link.btn-expand-table"
        );

        expandTableBtn?.removeEventListener(
          "click",
          generateFullScreenTableModal
        );
        editTableBtn?.removeEventListener("click", generateSpreadsheetModal);
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

      api.cleanupStream(cleanupPopupBtns);
    });
  },
};
