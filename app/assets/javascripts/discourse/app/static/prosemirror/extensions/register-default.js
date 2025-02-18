import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import quote from "./quote";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [quote];

defaultExtensions.forEach(registerRichEditorExtension);
