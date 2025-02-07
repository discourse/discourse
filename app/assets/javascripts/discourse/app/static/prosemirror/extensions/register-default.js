import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import codeBlock from "./code-block";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [codeBlock];

defaultExtensions.forEach(registerRichEditorExtension);
