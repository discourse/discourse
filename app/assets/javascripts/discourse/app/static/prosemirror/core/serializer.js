import {
  defaultMarkdownSerializer,
  MarkdownSerializer,
} from "prosemirror-markdown";

export default class Serializer {
  #pmSerializer;

  constructor(extensions, pluginParams, includeDefault = true) {
    this.nodes = includeDefault ? { ...defaultMarkdownSerializer.nodes } : {};
    this.nodes.hard_break = (state) => state.write("\n");

    this.marks = includeDefault ? { ...defaultMarkdownSerializer.marks } : {};

    this.#extractNodeSerializers(extensions, pluginParams);
    this.#extractMarkSerializers(extensions, pluginParams);

    this.#pmSerializer = new MarkdownSerializer(this.nodes, this.marks);
  }

  convert(doc) {
    return this.#pmSerializer.serialize(doc);
  }

  #extractNodeSerializers(extensions, pluginParams) {
    for (const { serializeNode } of extensions) {
      const serializer =
        typeof serializeNode === "function"
          ? serializeNode(pluginParams)
          : serializeNode;
      Object.assign(this.nodes, serializer);
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
