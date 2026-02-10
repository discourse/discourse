/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    check: {
      attrs: { checked: { default: false } },
      inline: true,
      group: "inline",
      draggable: true,
      selectable: false,
      toDOM(node) {
        return [
          "span",
          {
            class: node.attrs.checked
              ? "chcklst-box checked fa fa-square-check-o"
              : "chcklst-box fa fa-square-o",
          },
        ];
      },
      parseDOM: [
        {
          tag: "span.chcklst-box",
          getAttrs: (dom) => ({ checked: hasCheckedClass(dom.className) }),
        },
      ],
    },
  },

  inputRules: [
    {
      match: /(^|\s)\[(x? ?)]$/,
      handler: (state, match, start, end) => {
        const checkNode = state.schema.nodes.check.create({
          checked: match[2] === "x",
        });
        const spaceNode = state.schema.text(" ");
        return state.tr.replaceWith(start + match[1].length, end, [
          checkNode,
          spaceNode,
        ]);
      },
    },
  ],

  parse: {
    check_open: {
      node: "check",
      getAttrs: (token) => ({
        checked: hasCheckedClass(token.attrGet("class")),
      }),
    },
    check_close: { noCloseToken: true, ignore: true },
  },

  serializeNode: {
    check: (state, node) => {
      state.write(node.attrs.checked ? "[x]" : "[ ]");
    },
  },

  plugins({
    pmState: { Plugin },
    pmView: { Decoration, DecorationSet },
    schema,
    utils: { changedDescendants },
  }) {
    const checkType = schema.nodes.check;
    const listItemType = schema.nodes.list_item;
    const bulletListType = schema.nodes.bullet_list;

    const startsWithCheck = (node) =>
      node?.isTextblock && node.firstChild?.type === checkType;

    const findBulletListContext = ($from) => {
      for (let depth = $from.depth; depth > 0; depth--) {
        if ($from.node(depth).type === listItemType) {
          if ($from.node(depth - 1)?.type === bulletListType) {
            return { bulletListDepth: depth - 1, listItemDepth: depth };
          }
          return null;
        }
      }
      return null;
    };

    const inBulletListItem = (doc, pos) =>
      findBulletListContext(doc.resolve(pos)) !== null;

    const ensureSpaceAfterChecks = (tr, oldState, newState) => {
      const positionsToInsert = [];

      changedDescendants(oldState.doc, newState.doc, (node, pos) => {
        if (!startsWithCheck(node) || !inBulletListItem(newState.doc, pos)) {
          return;
        }

        const secondChild = node.childCount > 1 ? node.child(1) : null;
        const hasSpaceAfter =
          secondChild?.isText && secondChild.text?.[0] === " ";

        if (!hasSpaceAfter) {
          positionsToInsert.push(pos + 1 + node.firstChild.nodeSize);
        }
      });

      for (let i = positionsToInsert.length - 1; i >= 0; i--) {
        tr.insert(positionsToInsert[i], schema.text(" "));
      }
    };

    const exitChecklist = (tr, ctx) => {
      const { bulletListDepth, listItemDepth } = ctx;
      const { selection } = tr;
      const { $from } = selection;
      const bulletList = $from.node(bulletListDepth);
      const listItemIndex = $from.index(bulletListDepth);
      const prevListItem = bulletList.child(listItemIndex - 1);
      const bulletListStart = $from.before(bulletListDepth);

      tr.delete($from.before(listItemDepth), $from.after(listItemDepth));

      let prevOffset = 1;
      for (let i = 0; i < listItemIndex - 1; i++) {
        prevOffset += bulletList.child(i).nodeSize;
      }
      const prevItemStart = tr.mapping.map(bulletListStart + prevOffset);
      tr.delete(prevItemStart, prevItemStart + prevListItem.nodeSize);

      const mappedListStart = tr.mapping.map(bulletListStart);
      const listAfter = tr.doc.nodeAt(mappedListStart);

      if (listAfter && listAfter.childCount > 0) {
        const listEnd = mappedListStart + listAfter.nodeSize;
        tr.insert(listEnd, schema.nodes.paragraph.create());
        tr.setSelection(
          selection.constructor.near(tr.doc.resolve(listEnd + 1))
        );
      } else {
        tr.replaceWith(
          mappedListStart,
          mappedListStart + (listAfter?.nodeSize || 0),
          schema.nodes.paragraph.create()
        );
        tr.setSelection(
          selection.constructor.near(tr.doc.resolve(mappedListStart + 1))
        );
      }
      return tr;
    };

    const handleChecklistContinuation = (tr, transactions) => {
      if (!transactions.some((t) => t.docChanged)) {
        return null;
      }

      const { selection } = tr;
      const { $from } = selection;

      if (!selection.empty) {
        return null;
      }

      const parent = $from.parent;
      if (!parent.isTextblock || parent.content.size !== 0) {
        return null;
      }

      const ctx = findBulletListContext($from);
      if (!ctx) {
        return null;
      }

      const bulletList = $from.node(ctx.bulletListDepth);
      const listItemIndex = $from.index(ctx.bulletListDepth);
      if (listItemIndex === 0) {
        return null;
      }

      const prevParagraph = bulletList.child(listItemIndex - 1).firstChild;
      if (!startsWithCheck(prevParagraph)) {
        return null;
      }

      if (prevParagraph.content.size > 2) {
        const checkNode = checkType.create({ checked: false });
        tr.insert($from.pos, [checkNode, schema.text(" ")]);
        tr.setSelection(
          selection.constructor.near(tr.doc.resolve($from.pos + 2))
        );
        return tr;
      }

      return exitChecklist(tr, ctx);
    };

    const adjustCursorPosition = (tr) => {
      const { doc, selection } = tr;
      const { $from } = selection;

      if (!selection.empty) {
        return null;
      }

      const parent = $from.parent;
      if (!startsWithCheck(parent) || !inBulletListItem(doc, $from.pos)) {
        return null;
      }

      const checkSize = parent.firstChild.nodeSize;
      const secondChild = parent.childCount > 1 ? parent.child(1) : null;
      const hasSpaceAfter =
        secondChild?.isText && secondChild.text?.[0] === " ";
      const minPos = hasSpaceAfter ? checkSize + 1 : checkSize;

      if ($from.parentOffset < minPos) {
        tr.setSelection(
          selection.constructor.near(doc.resolve($from.start() + minPos))
        );
        return tr;
      }

      return null;
    };

    return [
      new Plugin({
        props: {
          handleClickOn(view, pos, node, nodePos) {
            if (node.type.name === "check") {
              view.dispatch(
                view.state.tr.setNodeMarkup(nodePos, null, {
                  checked: !node.attrs.checked,
                })
              );
              return true;
            }
            return false;
          },

          handleKeyDown(view, event) {
            if (event.key !== "Backspace" && event.key !== "ArrowLeft") {
              return false;
            }

            const { state, dispatch } = view;
            const { selection } = state;
            const { $from } = selection;

            // Only handle at position 2 (right after check+space) in a checklist
            if (
              !selection.empty ||
              $from.parentOffset !== 2 ||
              !startsWithCheck($from.parent) ||
              !inBulletListItem(state.doc, $from.pos)
            ) {
              return false;
            }

            if (event.key === "Backspace") {
              const ctx = findBulletListContext($from);

              const checkStart = $from.start();
              let tr = state.tr.delete(checkStart, checkStart + 2);

              if (ctx) {
                const listItemPos = tr.mapping.map(
                  $from.before(ctx.listItemDepth)
                );
                const $listItem = tr.doc.resolve(listItemPos);

                if ($listItem.nodeBefore?.type === listItemType) {
                  tr = tr.join(listItemPos, 2);
                }
              }

              dispatch(tr);
              return true;
            }

            const beforeTextblock = $from.before();
            if (beforeTextblock > 0) {
              dispatch(
                state.tr.setSelection(
                  selection.constructor.near(
                    state.doc.resolve(beforeTextblock),
                    -1
                  )
                )
              );
              return true;
            }

            return false;
          },
        },

        appendTransaction(transactions, oldState, newState) {
          const isFullReplace = transactions.some(
            (t) =>
              t.steps.length === 1 &&
              t.steps[0].from === 0 &&
              t.steps[0].to === oldState.doc.content.size
          );
          if (isFullReplace) {
            return null;
          }

          const tr = newState.tr;
          ensureSpaceAfterChecks(tr, oldState, newState);

          return (
            handleChecklistContinuation(tr, transactions) ??
            adjustCursorPosition(tr) ??
            (tr.docChanged ? tr : null)
          );
        },
      }),

      // Decoration plugin to add has-checkbox class to checklist items
      new Plugin({
        props: {
          decorations(state) {
            const decorations = [];

            state.doc.descendants((node, pos, parent) => {
              if (
                node.type === listItemType &&
                parent?.type === bulletListType &&
                startsWithCheck(node.firstChild)
              ) {
                decorations.push(
                  Decoration.node(pos, pos + node.nodeSize, {
                    class: "has-checkbox",
                  })
                );
              }
            });

            return DecorationSet.create(state.doc, decorations);
          },
        },
      }),
    ];
  },

  commands: ({ schema, pmSchemaList }) => {
    const checkType = schema.nodes.check;
    const bulletListType = schema.nodes.bullet_list;
    const orderedListType = schema.nodes.ordered_list;
    const listItemType = schema.nodes.list_item;

    const listItemHasCheck = (listItem) => {
      const p = listItem.firstChild;
      return p?.isTextblock && p.firstChild?.type === checkType;
    };

    const findListContext = (state) => {
      const { $from, $to } = state.selection;
      for (let depth = $from.depth; depth > 0; depth--) {
        if ($from.node(depth).type === listItemType) {
          const list = $from.node(depth - 1);
          if (list?.type === bulletListType || list?.type === orderedListType) {
            return {
              listDepth: depth - 1,
              listItemDepth: depth,
              listType: list.type,
              list,
              listStart: $from.before(depth - 1),
              $from,
              $to,
            };
          }
        }
      }
      return null;
    };

    const forEachSelectedItem = (ctx, callback) => {
      const { list, listStart, $from, $to } = ctx;
      const collapsed = $from.pos === $to.pos;

      list.forEach((item, offset) => {
        const itemStart = listStart + 1 + offset;
        const itemEnd = itemStart + item.nodeSize;
        const inSelection = collapsed
          ? $from.pos >= itemStart && $from.pos <= itemEnd
          : !(itemEnd <= $from.pos || itemStart >= $to.pos);

        if (inSelection) {
          callback(item, itemStart);
        }
      });
    };

    const hasCheckInSelection = (ctx) => {
      if (!ctx || ctx.listType !== bulletListType) {
        return false;
      }
      let found = false;
      forEachSelectedItem(ctx, (item) => {
        if (listItemHasCheck(item)) {
          found = true;
        }
      });
      return found;
    };

    const removeChecksFromSelection = (state, ctx) => {
      const toDelete = [];
      forEachSelectedItem(ctx, (item, itemStart) => {
        if (listItemHasCheck(item)) {
          const textblock = item.firstChild;
          const checkSize = textblock.firstChild.nodeSize;
          const second = textblock.childCount > 1 ? textblock.child(1) : null;
          const hasSpace = second?.isText && second.text?.[0] === " ";
          toDelete.push({
            from: itemStart + 2,
            to: itemStart + 2 + checkSize + (hasSpace ? 1 : 0),
          });
        }
      });

      let tr = state.tr;
      for (let i = toDelete.length - 1; i >= 0; i--) {
        tr = tr.delete(toDelete[i].from, toDelete[i].to);
      }
      return tr;
    };

    const addChecksToSelection = (state, ctx) => {
      const toInsert = [];
      forEachSelectedItem(ctx, (item, itemStart) => {
        if (!listItemHasCheck(item) && item.firstChild?.isTextblock) {
          toInsert.push(itemStart + 2);
        }
      });

      let tr = state.tr;
      let offset = 0;
      for (const pos of toInsert) {
        const check = checkType.create({ checked: false });
        const space = schema.text(" ");
        tr = tr.insert(pos + offset, [check, space]);
        offset += check.nodeSize + space.nodeSize;
      }
      return tr;
    };

    return {
      toggleBulletList() {
        return (state, dispatch) => {
          const ctx = findListContext(state);
          if (hasCheckInSelection(ctx)) {
            if (dispatch) {
              dispatch(removeChecksFromSelection(state, ctx));
            }
            return true;
          }
          return false;
        };
      },

      toggleOrderedList() {
        return (state, dispatch, view) => {
          const ctx = findListContext(state);
          if (!hasCheckInSelection(ctx)) {
            return false;
          }

          if (!dispatch) {
            return true;
          }

          const liftListItem = pmSchemaList?.liftListItem;
          const wrapInList = pmSchemaList?.wrapInList;
          if (!liftListItem || !wrapInList) {
            return false;
          }

          dispatch(removeChecksFromSelection(state, ctx));
          if (view) {
            liftListItem(listItemType)(view.state, dispatch);
            wrapInList(orderedListType)(view.state, dispatch);
          }
          return true;
        };
      },

      toggleChecklist() {
        return (state, dispatch, view) => {
          const ctx = findListContext(state);
          const wrapInList = pmSchemaList?.wrapInList;
          const liftListItem = pmSchemaList?.liftListItem;

          if (hasCheckInSelection(ctx)) {
            if (!dispatch || !liftListItem) {
              return !!liftListItem;
            }
            dispatch(removeChecksFromSelection(state, ctx));
            if (view) {
              liftListItem(listItemType)(view.state, dispatch);
            }
            return true;
          }

          if (ctx?.listType === bulletListType) {
            if (dispatch) {
              dispatch(addChecksToSelection(state, ctx));
            }
            return true;
          }

          if (ctx?.listType === orderedListType) {
            if (!dispatch || !liftListItem || !wrapInList) {
              return !!(liftListItem && wrapInList);
            }
            liftListItem(listItemType)(state, dispatch);
            if (view) {
              wrapInList(bulletListType)(view.state, dispatch);
              const newCtx = findListContext(view.state);
              if (newCtx) {
                dispatch(addChecksToSelection(view.state, newCtx));
              }
            }
            return true;
          }

          if (!wrapInList) {
            return false;
          }
          if (!dispatch) {
            return wrapInList(bulletListType)(state, undefined);
          }

          wrapInList(bulletListType)(state, dispatch);
          if (view) {
            const newCtx = findListContext(view.state);
            if (newCtx) {
              dispatch(addChecksToSelection(view.state, newCtx));
            }
          }
          return true;
        };
      },
    };
  },

  state: ({ schema, utils: { inNode } }, viewState) => {
    const { $from } = viewState.selection;
    let inCheckList = false;

    for (let depth = $from.depth; depth > 0; depth--) {
      const node = $from.node(depth);
      if (node.type === schema.nodes.list_item) {
        if ($from.node(depth - 1)?.type === schema.nodes.bullet_list) {
          const p = node.firstChild;
          inCheckList =
            p?.isTextblock && p.firstChild?.type === schema.nodes.check;
        }
        break;
      }
    }

    return {
      inCheckList,
      inBulletList: !inCheckList && inNode(viewState, schema.nodes.bullet_list),
    };
  },
};

const CHECKED_REGEX = /\bchecked\b/;

function hasCheckedClass(className) {
  return CHECKED_REGEX.test(className);
}

export default extension;
