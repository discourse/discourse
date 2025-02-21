import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import strikethrough from "./strikethrough";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [strikethrough];

defaultExtensions.forEach(registerRichEditorExtension);
