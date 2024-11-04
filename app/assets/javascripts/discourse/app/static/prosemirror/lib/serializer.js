import {
  defaultMarkdownSerializer,
  MarkdownSerializer,
} from "prosemirror-markdown";
import {
  getMarkSerializers,
  getNodeSerializers,
} from "discourse/lib/composer/rich-editor-extensions";

const serializeNodes = {
  ...defaultMarkdownSerializer.nodes,

  // Custom
  hard_break(state) {
    state.write("\n");
  },
  ...getNodeSerializers(),
};

const serializeMarks = {
  ...defaultMarkdownSerializer.marks,

  // Custom
  ...getMarkSerializers(),
};

export function convertToMarkdown(doc) {
  // console.log("Doc to serialize", doc);

  return new MarkdownSerializer(serializeNodes, serializeMarks).serialize(doc);
}
