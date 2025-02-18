import { registerRichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";
import link from "./link";

/**
 * List of default extensions
 * ProsemirrorEditor autoloads them when includeDefault=true (the default)
 *
 * @type {RichEditorExtension[]}
 */
const defaultExtensions = [link];

defaultExtensions.forEach(registerRichEditorExtension);
