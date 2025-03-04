import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import emoji from "./emoji";
import hashtag from "./hashtag";
import heading from "./heading";
import mention from "./mention";
import underline from "./underline";
import image from "./image";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [emoji, image, heading, hashtag, mention, underline];

defaultExtensions.forEach(registerRichEditorExtension);

export default defaultExtensions;
