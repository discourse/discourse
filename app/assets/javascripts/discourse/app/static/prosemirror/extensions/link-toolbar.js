import ToolbarButtons from "discourse/components/composer/toolbar-buttons";
import InsertHyperlink from "discourse/components/modal/insert-hyperlink";
import { ToolbarBase } from "discourse/lib/composer/toolbar";
import { rovingButtonBar } from "discourse/lib/roving-button-bar";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import { updatePosition } from "float-kit/lib/update-position";

const AUTO_LINKS = ["autolink", "linkify"];
const MENU_OFFSET = 12;

class LinkToolbar extends ToolbarBase {
  constructor(opts = {}) {
    super(opts);

    this.addButton({
      id: "link-edit",
      icon: "pen",
      title: "composer.link_toolbar.edit",
      className: "composer-link-toolbar__edit",
      preventFocus: true,
      action: opts.editLink,
    });

    this.addButton({
      id: "link-copy",
      icon: "copy",
      title: "composer.link_toolbar.copy",
      className: "composer-link-toolbar__copy",
      preventFocus: true,
      action: opts.copyLink,
    });

    this.addButton({
      id: "link-unlink",
      icon: "link-slash",
      title: "composer.link_toolbar.remove",
      className: "composer-link-toolbar__unlink",
      preventFocus: true,
      condition: opts.canUnlink,
      action: opts.unlinkText,
    });

    this.addSeparator({ condition: opts.canVisit });

    this.addButton({
      id: "link-visit",
      icon: "up-right-from-square",
      title: "composer.link_toolbar.visit",
      className: "btn-flat composer-link-toolbar__visit",
      preventFocus: true,
      href: opts.getHref,
      condition: opts.canVisit,
    });
  }
}

/** @type {RichEditorExtension} */
const extension = {
  plugins: ({ pmState: { Plugin, TextSelection }, utils, getContext }) => {
    return new Plugin({
      props: {
        handleKeyDown(view, event) {
          if (event.key !== "Tab" || event.shiftKey) {
            return false;
          }

          const range = utils.getMarkRange(
            view.state.selection.$head,
            view.state.schema.marks.link
          );
          if (!range) {
            return false;
          }

          const activeMenu = document.querySelector(
            '[data-identifier="composer-link-toolbar"]'
          );
          if (!activeMenu) {
            return false;
          }

          event.preventDefault();

          const focusable = activeMenu.querySelector(
            'button, a, [tabindex]:not([tabindex="-1"]), .select-kit'
          );

          if (focusable) {
            focusable.focus();
            return true;
          }

          return false;
        },
      },

      view() {
        let menuInstance;
        let toolbarReplaced = false;
        let linkToolbar;
        let linkState;

        return {
          update(view) {
            const markRange = utils.getMarkRange(
              view.state.selection.$head,
              view.state.schema.marks.link
            );

            if (!markRange) {
              menuInstance?.destroy();
              menuInstance = null;

              if (toolbarReplaced) {
                getContext().replaceToolbar(null);
                toolbarReplaced = false;
              }
              return;
            }

            const attrs = {
              ...markRange.mark.attrs,
              range: markRange,
              head: view.state.selection.head,
            };

            let shouldUpdateMenu =
              menuInstance?.expanded &&
              linkState?.range?.from === attrs.range?.from &&
              linkState?.range?.to === attrs.range?.to;

            if (!linkToolbar) {
              linkState = attrs;

              const handlers = {
                editLink: () => {
                  const linkData = linkState;

                  const tempTr = view.state.tr.removeMark(
                    linkData.range.from,
                    linkData.range.to,
                    view.state.schema.marks.link
                  );

                  const currentLinkText = utils.convertToMarkdown(
                    view.state.schema.topNodeType.create(
                      null,
                      view.state.schema.nodes.paragraph.create(
                        null,
                        tempTr.doc.slice(linkData.range.from, linkData.range.to)
                          .content
                      )
                    )
                  );

                  getContext().modal.show(InsertHyperlink, {
                    model: {
                      editing: true,
                      linkText: currentLinkText,
                      linkUrl: linkData.href,
                      toolbarEvent: {
                        addText: (text) => {
                          const { content } = utils.convertFromMarkdown(text);
                          const range = linkData.range;

                          if (content.firstChild?.content.size > 0) {
                            const { state, dispatch } = view;
                            const tr = state.tr.replaceWith(
                              range.from,
                              range.to,
                              content.firstChild.content
                            );

                            const newPos = Math.min(
                              view.state.selection.from,
                              range.from + content.firstChild.content.size
                            );
                            const resolvedPos = tr.doc.resolve(newPos);
                            tr.setSelection(
                              new TextSelection(resolvedPos, resolvedPos)
                            );
                            dispatch(tr);
                            view.focus();
                          }
                        },
                      },
                    },
                  });
                },

                copyLink: async () => {
                  await clipboardCopy(linkState.href);
                  getContext().toasts.success({
                    duration: "short",
                    data: {
                      message: i18n("composer.link_toolbar.link_copied"),
                    },
                  });
                },

                unlinkText: () => {
                  const range = view.state.selection.empty
                    ? linkState.range
                    : view.state.selection;
                  if (range) {
                    const { state, dispatch } = view;
                    dispatch(
                      state.tr.removeMark(
                        range.from,
                        range.to,
                        state.schema.marks.link
                      )
                    );
                    view.focus();
                  }
                },

                canVisitLink: () => {
                  return utils
                    ? !!utils.getLinkify().matchAtStart(linkState.href)
                    : false;
                },

                getHref: () => linkState.href,

                canUnlink: () => !AUTO_LINKS.includes(linkState.markup),
              };

              linkToolbar = new LinkToolbar(handlers);
              linkToolbar.rovingButtonBar = (event) => {
                if (event.key === "Tab") {
                  event.preventDefault();
                  view.focus();
                  return false;
                }
                return rovingButtonBar(event);
              };
            } else {
              linkState = attrs;
            }

            if (getContext().capabilities.viewport.sm) {
              const element = view.domAtPos(attrs.head).node;
              const trigger =
                element.nodeType === Node.TEXT_NODE
                  ? element.parentElement
                  : element;

              trigger.getBoundingClientRect = () => {
                if (!view.docView) {
                  return {};
                }

                const { left, top } = view.coordsAtPos(attrs.head);
                return {
                  left,
                  top: top + MENU_OFFSET,
                  width: 0,
                  height: 0,
                };
              };

              if (menuInstance) {
                if (shouldUpdateMenu) {
                  menuInstance.trigger = trigger;
                  updatePosition(
                    menuInstance.trigger,
                    menuInstance.content,
                    {}
                  );
                  return;
                } else {
                  menuInstance.destroy();
                }
              }

              getContext()
                .menu.show(trigger, {
                  portalOutletElement: view.dom.parentElement,
                  identifier: "composer-link-toolbar",
                  component: ToolbarButtons,
                  placement: "bottom",
                  padding: 0,
                  boundary: view.dom.parentElement,
                  fallbackPlacements: [
                    "bottom-end",
                    "bottom-start",
                    "top",
                    "top-end",
                    "top-start",
                  ],
                  closeOnClickOutside: false,
                  onClose: () => {
                    view.focus();
                  },
                  data: linkToolbar,
                })
                .then((instance) => {
                  menuInstance = instance;
                });
            } else {
              getContext().replaceToolbar(linkToolbar);
              toolbarReplaced = true;
            }
          },

          destroy() {
            menuInstance?.destroy();
            menuInstance = null;
            linkToolbar = null;
          },
        };
      },
    });
  },
};

export default extension;
