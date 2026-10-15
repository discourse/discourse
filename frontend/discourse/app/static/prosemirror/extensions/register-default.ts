import {
  markDefaultExtensionsRegistered,
  registerRichEditorExtension,
  type RichEditorExtension,
} from "discourse/lib/composer/rich-editor-extensions";
import bulletList from "./bullet-list.js";
import code from "./code.ts";
import codeBlock from "./code-block.js";
import emoji from "./emoji.js";
import grid from "./grid.js";
import hardBreak from "./hard-break.ts";
import hashtag from "./hashtag.js";
import heading from "./heading.js";
import htmlBlock from "./html-block.js";
import htmlInline from "./html-inline.js";
import image from "./image.js";
import link from "./link.ts";
import linkToolbar from "./link-toolbar.js";
import markdownPaste from "./markdown-paste.js";
import mention from "./mention.js";
import onebox from "./onebox.js";
import oneboxToolbar from "./onebox-toolbar.js";
import orderedList from "./ordered-list.js";
import overrideDragGhost from "./override-drag-ghost.ts";
import previewSource from "./preview-source.js";
import previewToolbar from "./preview-toolbar.js";
import quote from "./quote.js";
import strikethrough from "./strikethrough.ts";
import strong from "./strong.ts";
import table from "./table.js";
import trailingInlineSpace from "./trailing-inline-space.ts";
import trailingParagraph from "./trailing-paragraph.ts";
import underline from "./underline.ts";
import uploadPlaceholder from "./upload-placeholder.js";
import wordPaste from "./word-paste.js";
import wrap from "./wrap.js";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 */
const defaultExtensions: RichEditorExtension[] = [
  emoji,
  image,
  onebox,
  oneboxToolbar,
  code,
  link,
  linkToolbar,
  heading,
  codeBlock,
  quote,
  hashtag,
  mention,
  strikethrough,
  strong,
  underline,
  htmlInline,
  htmlBlock,
  trailingParagraph,
  table,
  markdownPaste,
  wordPaste,
  orderedList,
  bulletList,
  wrap,
  trailingInlineSpace,
  overrideDragGhost,
  hardBreak,
  grid,
  uploadPlaceholder,
  previewSource,
  previewToolbar,
];

defaultExtensions.forEach(registerRichEditorExtension);
markDefaultExtensionsRegistered();

export default defaultExtensions;
