import {
  defaultMarkdownSerializer,
  MarkdownSerializerState,
} from "prosemirror-markdown";
import expelBoundaryPunctuation from "../lib/expel-boundary-punctuation";

export default class Serializer {
  #afterSerializers;

  constructor(extensions, pluginParams, includeDefault = true) {
    this.nodes = includeDefault ? { ...defaultMarkdownSerializer.nodes } : {};
    this.nodes.hard_break = (state) =>
      state.write(state.inTable ? "<br>" : "\n");

    this.nodes.text = (state, node) => {
      // A text run whose entire content is a single `[..]` pair comes from
      // typed BBCode (e.g. `[details="Summary"]`, `[/details]`, `[spoiler]`).
      // Escaping the brackets to `\[..\]` would let discourse-math's LaTeX
      // delimiter mode consume the line as display math and lose the BBCode.
      if (/^\s*\[[^\]]*\]\s*$/.test(node.text)) {
        state.text(node.text, false);
        return;
      }
      state.text(node.text, !state.inAutolink);
    };

    this.marks = includeDefault ? { ...defaultMarkdownSerializer.marks } : {};

    this.#extractNodeSerializers(extensions, pluginParams);
    this.#extractMarkSerializers(extensions, pluginParams);
  }

  convert(doc) {
    const state = new MarkdownSerializerState(this.nodes, this.marks, {});
    state.renderContent(expelBoundaryPunctuation(doc).content);

    if (this.#afterSerializers) {
      for (const afterSerializer of this.#afterSerializers) {
        afterSerializer(state);
      }
    }

    return state.out;
  }

  #addAfterSerializer(callback) {
    if (!callback) {
      return;
    }

    this.#afterSerializers ??= [];
    this.#afterSerializers.push(callback);
  }

  #extractNodeSerializers(extensions, pluginParams) {
    for (const { serializeNode } of extensions) {
      const serializer =
        typeof serializeNode === "function"
          ? serializeNode(pluginParams)
          : serializeNode;

      Object.assign(this.nodes, serializer);
      this.#addAfterSerializer(serializer?.afterSerialize);
    }
  }

  #extractMarkSerializers(extensions, pluginParams) {
    for (const { serializeMark } of extensions) {
      const serializer =
        typeof serializeMark === "function"
          ? serializeMark(pluginParams)
          : serializeMark;
      Object.assign(this.marks, serializer);
    }
  }
}
