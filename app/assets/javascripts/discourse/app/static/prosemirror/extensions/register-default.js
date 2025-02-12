import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import mention from "./mention";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [mention];

defaultExtensions.forEach(registerRichEditorExtension);
