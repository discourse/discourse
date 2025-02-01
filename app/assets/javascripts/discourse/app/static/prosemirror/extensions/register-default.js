import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [];

defaultExtensions.forEach(registerRichEditorExtension);
