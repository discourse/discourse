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
    return extensions.reduce((acc, { serializeNode }) => {
      Object.assign(acc, serializeNode);
      return acc;
    }, this.nodes);
  }

  #extractMarkSerializers(extensions) {
    return extensions.reduce((acc, { serializeMark }) => {
      Object.assign(acc, serializeMark);
      return acc;
    }, this.marks);
  }
}
