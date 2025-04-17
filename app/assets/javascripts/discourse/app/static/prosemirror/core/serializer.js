import {
  defaultMarkdownSerializer,
  MarkdownSerializerState,
} from "prosemirror-markdown";

export default class Serializer {
  #afterSerializers;

  constructor(extensions, pluginParams, includeDefault = true) {
    this.nodes = includeDefault ? { ...defaultMarkdownSerializer.nodes } : {};
    this.nodes.hard_break = (state) => state.write("\n");

    this.marks = includeDefault ? { ...defaultMarkdownSerializer.marks } : {};

    this.#extractNodeSerializers(extensions, pluginParams);
    this.#extractMarkSerializers(extensions, pluginParams);
  }

  convert(doc) {
    const state = new MarkdownSerializerState(this.nodes, this.marks, {});
    state.renderContent(doc.content);

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
