import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import image from "./image";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [image];

defaultExtensions.forEach(registerRichEditorExtension);
