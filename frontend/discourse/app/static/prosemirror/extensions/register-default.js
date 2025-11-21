// @ts-check

import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import bulletList from "./bullet-list";
import code from "./code";
import codeBlock from "./code-block";
import emoji from "./emoji";
import grid from "./grid";
import hardBreak from "./hard-break";
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
import overrideDragGhost from "./override-drag-ghost";
import quote from "./quote";
import strikethrough from "./strikethrough";
import table from "./table";
import trailingInlineSpace from "./trailing-inline-space";
import trailingParagraph from "./trailing-paragraph";
import typographerReplacements from "./typographer-replacements";
import underline from "./underline";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension[]}
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
  trailingInlineSpace,
  overrideDragGhost,
  hardBreak,
  grid,
];

defaultExtensions.forEach(registerRichEditorExtension);

export default defaultExtensions;
