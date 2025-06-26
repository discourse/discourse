// @ts-check

/**
 * Interface for text manipulation with an underlying editor implementation.
 *
 * @interface TextManipulation
 */
export const TextManipulation = {};

/**
 * @typedef ToolbarState
 * @property {boolean} [inBold]
 * @property {boolean} [inItalic]
 * @property {boolean} [inLink]
 * @property {boolean} [inBulletList]
 * @property {boolean} [inOrderedList]
 * @property {boolean} [inCode]
 * @property {boolean} [inCodeBlock]
 * @property {boolean} [inBlockquote]
 */

/**
 * The current state of the editor for toolbar button active states
 * @name TextManipulation#state
 * @type {ToolbarState | undefined}
 * @readonly
 */

/**
 * Whether the editor allows a preview being shown
 * @name TextManipulation#allowPreview
 * @type {boolean}
 * @readonly
 */

/**
 * Focuses the editor
 *
 * @method
 * @name TextManipulation#focus
 * @returns {void}
 */

/**
 * Blurs and focuses the editor
 *
 * @method
 * @name TextManipulation#blurAndFocus
 * @returns {void}
 */

/**
 * Indents/un-indents the current selection
 *
 * @method
 * @name TextManipulation#indentSelection
 * @param {string} direction The direction to indent in. Either "right" or "left"
 * @returns {void}
 */

/**
 * Configures an Autocomplete for the editor
 *
 * @method
 * @name TextManipulation#autocomplete
 * @param {unknown} options The options for the jQuery autocomplete
 * @returns {void}
 */

/**
 * Checks if the current selection is in a code block
 *
 * @method
 * @name TextManipulation#inCodeBlock
 * @returns {Promise<boolean>}
 */

/**
 * Gets the current selection
 *
 * @method
 * @name TextManipulation#getSelected
 * @param {unknown} trimLeading
 * @returns {unknown}
 */

/**
 * Selects the text from the given range
 *
 * @method
 * @name TextManipulation#selectText
 * @param {number} from
 * @param {number} to
 * @param {unknown} [options]
 * @returns {void}
 */

/**
 * Applies the given head/tail to the selected text
 *
 * @method
 * @name TextManipulation#applySurround
 * @param {string} selected The selected text
 * @param {string} head The text to be inserted before the selection
 * @param {string} tail The text to be inserted after the selection
 * @param {string} exampleKey The key of the example
 * @param {unknown} [opts]
 */

/**
 * Applies the list format to the selected text
 *
 * @method
 * @name TextManipulation#applyList
 * @param {string} selected The selected text
 * @param {string} head The text to be inserted before the selection
 * @param {string} exampleKey The key of the example
 * @param {unknown} [opts]
 */

/**
 * Formats the current selection as code
 *
 * @method
 * @name TextManipulation#formatCode
 * @returns {void}
 */

/**
 * Adds text
 *
 * @method
 * @name TextManipulation#addText
 * @param {string} selected The selected text
 * @param {string} text The text to be inserted
 */

/**
 * Toggles the text (LTR/RTL) direction
 *
 * @method
 * @name TextManipulation#toggleDirection
 * @returns {void}
 */

/**
 * Replaces text
 *
 * @method
 * @name TextManipulation#replaceText
 * @param {string} oldValue The old value
 * @param {string} newValue The new value
 * @param {unknown} [opts]
 * @returns {void}
 */

/**
 * Handles the paste event
 *
 * @method
 * @name TextManipulation#paste
 * @param {ClipboardEvent} event The paste event
 * @returns {void}
 */

/**
 * Inserts the block
 *
 * @method
 * @name TextManipulation#insertBlock
 * @param {string} block The block to be inserted
 * @returns {void}
 */

/**
 * Inserts text
 *
 * @method
 * @name TextManipulation#insertText
 * @param {string} text The text to be inserted
 * @returns {void}
 */

/**
 * Applies the head/tail to the selected text
 *
 * @method
 * @name TextManipulation#applySurroundSelection
 * @param {string} head The text to be inserted before the selection
 * @param {string} tail The text to be inserted after the selection
 * @param {string} exampleKey The key of the example
 * @param {unknown} [opts]
 * @returns {void}
 */

/**
 * Puts cursor at the end of the editor
 *
 * @method
 * @name TextManipulation#putCursorAtEnd
 * @returns {void}
 */

/**
 * The placeholder handler instance
 *
 * @name TextManipulation#placeholder
 * @type {PlaceholderHandler}
 * @readonly
 */

/** @typedef {import("@uppy/utils/lib/UppyFile").MinimalRequiredUppyFile<any,any>} UppyFile */

/**
 * Interface for handling placeholders on upload events
 *
 * @interface PlaceholderHandler
 */
export const PlaceholderHandler = {};

/**
 * Inserts a file
 *
 * @method
 * @name PlaceholderHandler#insert
 * @param {UppyFile} file The uploaded file
 * @returns {void}
 */

/**
 * Success event for file upload
 *
 * @method
 * @name PlaceholderHandler#success
 * @param {UppyFile} file The uploaded file
 * @param {string} markdown The markdown for the uploaded file
 * @returns {void}
 */

/**
 * Cancels all uploads
 *
 * @method
 * @name PlaceholderHandler#cancelAll
 * @returns {void}
 */

/**
 * Cancels one uploaded file
 *
 * @method
 * @name PlaceholderHandler#cancel
 * @param {UppyFile} file The uploaded file
 * @returns {void}
 */

/**
 * Progress event
 *
 * @method
 * @name PlaceholderHandler#progress
 * @param {UppyFile} file The uploaded file
 * @returns {void}
 */

/**
 * Progress complete event
 *
 * @method
 * @name PlaceholderHandler#progressComplete
 * @param {UppyFile} file The uploaded file
 * @returns {void}
 */

/**
 * Interface for the Autocomplete handler
 *
 * @interface AutocompleteHandler
 */
export const AutocompleteHandler = {};

/**
 * Replaces the range with the given text
 *
 * @method
 * @name AutocompleteHandler#replaceTerm
 * @param {number} start The start of the range
 * @param {number} end The end of the range
 * @param {string} text The text to be inserted
 * @returns {void}
 */

/**
 * Gets the caret position
 *
 * @method
 * @name AutocompleteHandler#getCaretPosition
 * @returns {number}
 */

/**
 * Checks if the current selection is in a code block
 *
 * @method
 * @name AutocompleteHandler#inCodeBlock
 * @returns {Promise<boolean>}
 */

/**
 * Gets the caret coordinates
 *
 * @method
 * @name AutocompleteHandler#getCaretCoords
 * @param {number} caretPositon The caret position to get the coords for
 * @returns {{ top: number, left: number }}
 */

/**
 * Gets the current value for the autocomplete
 *
 * @method
 * @name AutocompleteHandler#getValue
 * @returns {string}
 */
