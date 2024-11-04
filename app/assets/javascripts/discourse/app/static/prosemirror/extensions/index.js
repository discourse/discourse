import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import codeBlock from "./code-block";
import emoji from "./emoji";
import hashtag from "./hashtag";
import heading from "./heading";
import htmlBlock from "./html-block";
import htmlInline from "./html-inline";
import image from "./image";
import link from "./link";
import markdownPaste from "./markdown-paste";
import mention from "./mention";
import onebox from "./onebox";
import quote from "./quote";
import strikethrough from "./strikethrough";
import table from "./table";
import trailingParagraph from "./trailing-paragraph";
import typographerReplacements from "./typographer-replacements";
import underline from "./underline";

const defaultExtensions = [
  emoji,
  // image must be after emoji
  image,
  hashtag,
  mention,
  strikethrough,
  underline,
  htmlInline,
  htmlBlock,
  link,
  heading,
  codeBlock,
  quote,
  onebox,
  trailingParagraph,
  typographerReplacements,
  markdownPaste,

  // table must  be last
  table,
];

defaultExtensions.forEach(registerRichEditorExtension);
