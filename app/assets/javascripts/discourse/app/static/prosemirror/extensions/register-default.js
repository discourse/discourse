import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import bulletList from "./bullet-list";
import code from "./code";
import codeBlock from "./code-block";
import emoji from "./emoji";
import hashtag from "./hashtag";
import heading from "./heading";
import htmlBlock from "./html-block";
import htmlInline from "./html-inline";
import image from "./image";
import link from "./link";
import linkToolbar from "./link-toolbar";
import markdownPaste from "./markdown-paste";
import mention from "./mention";
import onebox from "./onebox";
import orderedList from "./ordered-list";
import quote from "./quote";
import strikethrough from "./strikethrough";
import table from "./table";
import trailingParagraph from "./trailing-paragraph";
import typographerReplacements from "./typographer-replacements";
import underline from "./underline";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [
  emoji,
  image,
  onebox,
  code,
  link,
  linkToolbar,
  heading,
  codeBlock,
  quote,
  hashtag,
  mention,
  strikethrough,
  underline,
  htmlInline,
  htmlBlock,
  trailingParagraph,
  typographerReplacements,
  table,
  markdownPaste,
  orderedList,
  bulletList,
];

defaultExtensions.forEach(registerRichEditorExtension);

export default defaultExtensions;
