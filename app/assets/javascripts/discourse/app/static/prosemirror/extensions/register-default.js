import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import htmlInline from "./html-inline";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [htmlInline];

defaultExtensions.forEach(registerRichEditorExtension);
