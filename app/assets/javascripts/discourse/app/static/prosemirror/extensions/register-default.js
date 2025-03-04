import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import hashtag from "./hashtag";
import mention from "./mention";
import underline from "./underline";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [
  hashtag,
  mention,
  underline
];

defaultExtensions.forEach(registerRichEditorExtension);

export default defaultExtensions;
