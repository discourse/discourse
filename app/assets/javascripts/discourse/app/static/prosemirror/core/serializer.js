import {
  defaultMarkdownSerializer,
  MarkdownSerializer,
} from "prosemirror-markdown";

export default class Serializer {
  #pmSerializer;

  constructor(extensions, includeDefault = true) {
    this.nodes = includeDefault ? { ...defaultMarkdownSerializer.nodes } : {};
    this.nodes.hard_break = (state) => state.write("\n");

    this.marks = includeDefault ? { ...defaultMarkdownSerializer.marks } : {};

    this.#extractNodeSerializers(extensions);
    this.#extractMarkSerializers(extensions);

    this.#pmSerializer = new MarkdownSerializer(this.nodes, this.marks);
  }

  convert(doc) {
    return this.#pmSerializer.serialize(doc);
  }

  #extractNodeSerializers(extensions) {
    for (const { serializeNode } of extensions) {
      Object.assign(this.nodes, serializeNode);
    }
  }

  #extractMarkSerializers(extensions) {
    for (const { serializeMark } of extensions) {
      Object.assign(this.marks, serializeMark);
    }
  }
}
