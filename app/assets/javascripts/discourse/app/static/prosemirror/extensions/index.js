import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import codeLangSelector from "./code-lang-selector";
import emojiExtension from "./emoji";
import hashtagExtension from "./hashtag";
import headingExtension from "./heading";
import htmlBlockExtension from "./html-block";
import htmlInlineExtension from "./html-inline";
import imageExtension from "./image";
import linkExtension from "./link";
import markdownPasteExtension from "./markdown-paste";
import mentionExtension from "./mention";
import oneboxExtension from "./onebox";
import quoteExtension from "./quote";
import strikethroughExtension from "./strikethrough";
import tableExtension from "./table";
import typographerReplacements from "./typographer-replacements";
import underlineExtension from "./underline";

const defaultExtensions = [
  emojiExtension,
  // image must be after emoji
  imageExtension,
  hashtagExtension,
  mentionExtension,
  strikethroughExtension,
  underlineExtension,
  htmlInlineExtension,
  htmlBlockExtension,
  linkExtension,
  headingExtension,
  typographerReplacements,
  codeLangSelector,
  quoteExtension,

  oneboxExtension,

  markdownPasteExtension,

  // table must  be last
  tableExtension,
];

defaultExtensions.forEach(registerRichEditorExtension);
