import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { buildBBCodeAttrs } from "discourse/lib/text";
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
    const { node } = this.args;
    const optionCount = this.#optionList(node)?.node.childCount ?? 0;

    this.modal.show(PollUiBuilder, {
      model: {
        poll: { ...node.attrs, optionCount },
        onSave: (attrs) => this.#savePoll(attrs),
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

  #optionList(node) {
    const { bullet_list: bulletList } = this.args.pluginParams.schema.nodes;
    let offset = 1;

    for (let index = 0; index < node.childCount; index++) {
      const child = node.child(index);
      if (child.type === bulletList) {
        return { node: child, offset };
      }
      offset += child.nodeSize;
    }
  }

  #savePoll(attrs) {
    const { getPos, view, pluginParams } = this.args;
    const pos = getPos();
    if (pos === undefined || view.isDestroyed) {
      return;
    }

    const node = view.state.doc.nodeAt(pos);
    if (node?.type !== this.args.node.type) {
      return;
    }

    const tr = view.state.tr.setNodeMarkup(pos, null, attrs);

    if (attrs.type === "number") {
      // a number poll's options come from its range, so let the markdown
      // pipeline generate them instead of repeating the rules here
      const generated = pluginParams.utils.convertFromMarkdown(
        `[poll ${buildBBCodeAttrs(attrs)}]\n[/poll]`
      ).firstChild?.firstChild;
      const list = this.#optionList(node);

      if (list && generated?.type === list.node.type) {
        const from = pos + list.offset;
        tr.replaceWith(from, from + list.node.nodeSize, generated);
      }
    }

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
