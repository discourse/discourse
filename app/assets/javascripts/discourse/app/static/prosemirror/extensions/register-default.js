import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import emoji from "./emoji";
import hashtag from "./hashtag";
import heading from "./heading";
import image from "./image";
import link from "./link";
import mention from "./mention";
import quote from "./quote";
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
  link,
  heading,
  quote,
  hashtag,
  mention,
  underline,
];

defaultExtensions.forEach(registerRichEditorExtension);

export default defaultExtensions;
