export default {
  nodeSpec: {
    html_block: {
      attrs: { tag: {}, beforeContent: {}, afterContent: { default: null } },
      group: "block",
      content: "block*",
      selectable: true,
      isolating: true,
      draggable: true,
      parseDOM: [],
      toDOM: (node) => {
        const dom = document.createElement(node.attrs.tag);
        dom.classList.add("d-editor__html-block-wrapper");

        const template = document.createElement("template");
        template.innerHTML = node.attrs.beforeContent;
        // copy main el attrs to dom var, then append children from template
        for (const attr of template.content.firstChild.attributes) {
          dom.setAttribute(attr.name, attr.value);
        }
        for (const child of template.content.firstChild.childNodes) {
          dom.appendChild(child);
        }

        let contentDOM;
        if (node.content.size) {
          contentDOM = document.createElement("div");
          dom.appendChild(contentDOM);
        }

        return { dom, contentDOM };
      },
    },
  },
  parse: {
    html_block: (state, token) => {
      const openMatch = token.content.match(
        /^<([a-zA-Z][a-zA-Z0-9-]*)(?:\s[^>]*)?>.*/
      );
      const closeMatch = token.content.match(/^<\/([a-zA-Z][a-zA-Z0-9-]*)>/);

      if (openMatch) {
        state.openNode(state.schema.nodes.html_block, {
          tag: openMatch[1],
          beforeContent: token.content,
        });
      }

      if (
        closeMatch &&
        (openMatch?.[1] === closeMatch[1] ||
          state.top().attrs?.tag === closeMatch[1])
      ) {
        // if (state.top().attrs?.tag === closeMatch[1]) {
        //   state.top().attrs.afterContent = token.content;
        // }
        state.closeNode();
      }
    },
  },
  serializeNode: {
    html_block: (state, node) => {
      state.write(node.attrs.beforeContent);
      state.write("\n");
      state.renderContent(node);

      if (node.attrs.afterContent) {
        state.write(node.attrs.afterContent);
      } else {
        state.write(`</${node.attrs.tag}>`);
      }

      state.write("\n");
    },
  },
};
