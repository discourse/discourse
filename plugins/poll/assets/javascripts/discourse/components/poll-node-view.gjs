import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import PollUiBuilder from "./modal/poll-ui-builder";
import PollInfo from "./poll-info";

export default class PollNodeView extends Component {
  @service modal;

  constructor() {
    super(...arguments);
    this.args.contentDOM.classList.add(
      "poll-container",
      "composer-poll-node__content"
    );
    this.args.onSetup(this);
    this.update(this.args.node);
  }

  deselectNode() {
    this.args.dom.classList.remove("ProseMirror-selectednode");
  }

  @action
  editPoll() {
    const { node, pluginParams } = this.args;
    const { schema, utils } = pluginParams;
    const options = [];
    let title;
    let titleLevel;

    node.forEach((child) => {
      if (child.type === schema.nodes.heading) {
        titleLevel = child.attrs.level;
        title = utils
          .convertToMarkdown(
            schema.nodes.doc.create(
              null,
              schema.nodes.paragraph.create(null, child.content)
            )
          )
          .trim();
      } else if (child.type === schema.nodes.bullet_list) {
        child.forEach((item) => {
          options.push(utils.convertToMarkdown(item).trim());
        });
      }
    });

    this.modal.show(PollUiBuilder, {
      model: {
        poll: { ...node.attrs, title, titleLevel, options },
        onSave: (markdown) => this.#savePoll(markdown),
      },
    });
  }

  ignoreMutation(mutation) {
    return (
      mutation.type !== "selection" &&
      ((mutation.type === "attributes" &&
        mutation.target === this.args.contentDOM) ||
        !this.args.contentDOM.contains(mutation.target))
    );
  }

  selectNode() {
    this.args.dom.classList.add("ProseMirror-selectednode");
  }

  stopEvent(event) {
    return !!event.target.closest(".composer-poll-node__edit");
  }

  update(node) {
    const attrs = node.type.spec.toDOM(node)[1];
    for (const [name, value] of Object.entries(attrs)) {
      if (name === "class") {
        this.args.dom.classList.add(value);
      } else if (value === null) {
        this.args.dom.removeAttribute(name);
      } else {
        this.args.dom.setAttribute(name, value);
      }
    }
    this.args.contentDOM.contentEditable =
      node.attrs.type === "number" ? "false" : "true";
  }

  #savePoll(markdown) {
    const { getPos, view, pluginParams } = this.args;
    const pos = getPos();
    if (pos === undefined || view.isDestroyed) {
      return;
    }

    const node = view.state.doc.nodeAt(pos);
    const replacement =
      pluginParams.utils.convertFromMarkdown(markdown).firstChild;
    if (node?.type !== replacement?.type) {
      return;
    }

    const tr = view.state.tr.replaceWith(pos, pos + node.nodeSize, replacement);
    tr.setSelection(pluginParams.pmState.NodeSelection.create(tr.doc, pos));
    view.dispatch(tr);
    view.focus();
  }

  <template>
    <div class="composer-poll-node__info" contenteditable="false">
      <PollInfo @voters={{0}} />
    </div>
    <div
      class="poll-buttons composer-poll-node__actions"
      contenteditable="false"
    >
      <DButton
        class="btn-default composer-poll-node__edit"
        @action={{this.editPoll}}
        @icon="pencil"
        @label="poll.ui_builder.edit"
      />
    </div>
  </template>
}
