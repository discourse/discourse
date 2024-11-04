import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import codeLangSelector from "./code-lang-selector";
import emojiExtension from "./emoji";
import hashtagExtension from "./hashtag";
import headingExtension from "./heading";
import htmlInlineExtension from "./html-inline";
import imageExtension from "./image";
import linkExtension from "./link";
import mentionExtension from "./mention";
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
  linkExtension,
  headingExtension,
  typographerReplacements,
  codeLangSelector,
  quoteExtension,

  // table must  be last
  tableExtension,
];

defaultExtensions.forEach(registerRichEditorExtension);
