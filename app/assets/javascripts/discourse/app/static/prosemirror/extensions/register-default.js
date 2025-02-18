import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import htmlBlock from "./html-block";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [htmlBlock];

defaultExtensions.forEach(registerRichEditorExtension);
