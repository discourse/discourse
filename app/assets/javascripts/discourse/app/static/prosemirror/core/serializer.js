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

    extractNodeSerializers(extensions, this.nodes);
    extractMarkSerializers(extensions, this.marks);

    this.#pmSerializer = new MarkdownSerializer(this.nodes, this.marks);
  }

  convert(doc) {
    return this.#pmSerializer.serialize(doc);
  }
}

function extractNodeSerializers(extensions, nodes) {
  return extensions.reduce((acc, { serializeNode }) => {
    Object.assign(acc, serializeNode);
    return acc;
  }, nodes);
}

function extractMarkSerializers(extensions, marks) {
  return extensions.reduce((acc, { serializeMark }) => {
    Object.assign(acc, serializeMark);
    return acc;
  }, marks);
}
