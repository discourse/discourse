import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import table from "./table";

/**
 * List of default extensions

 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [table];

defaultExtensions.forEach(registerRichEditorExtension);
