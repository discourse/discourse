import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import emoji from "./emoji";
import heading from "./heading";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [emoji, heading];

defaultExtensions.forEach(registerRichEditorExtension);
