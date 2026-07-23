import type {
  Body,
  LocalUppyFileNonGhost,
  Meta,
  MinimalRequiredUppyFile,
} from "@uppy/utils";

export interface ToolbarState {
  /** Whether the selection has strong emphasis. */
  inBold?: boolean;
  /** Whether the selection has italic emphasis. */
  inItalic?: boolean;
  /** Whether the selection is inside a link. */
  inLink?: boolean;
  /** Whether the selection is inside a bullet list. */
  inBulletList?: boolean;
  /** Whether the selection is inside an ordered list. */
  inOrderedList?: boolean;
  /** Whether the selection has inline code formatting. */
  inCode?: boolean;
  /** Whether the selection is inside a code block. */
  inCodeBlock?: boolean;
  /** Whether the selection is inside a block quote. */
  inBlockquote?: boolean;
  /** Whether the selection is inside a heading. */
  inHeading?: boolean;
  /** Heading level at the selection. */
  inHeadingLevel?: number;
  /** Whether the selection is inside a paragraph. */
  inParagraph?: boolean;
}

export interface SelectedText {
  /** Start offset of the selection. */
  start: number;
  /** End offset of the selection. */
  end: number;
  /** Selected text. */
  value: string;
  /** Text before the selection. */
  pre: string;
  /** Text after the selection. */
  post: string;
  /** Full text of the line containing the selection. */
  lineVal?: string;
}

export interface SelectionOptions {
  /** Include the current line's text in the selection result. */
  lineVal?: boolean;
}

export interface SelectTextOptions {
  /** Restore scrolling, optionally to a supplied vertical position. */
  scroll?: boolean | number;
}

export interface ReplaceTextOptions {
  /** Zero-based match occurrence to replace. */
  index?: number;
  /** Pattern used to locate replacement candidates. */
  regex?: RegExp;
  /** Focus the editor after replacement. */
  forceFocus?: boolean;
  /** Preserve the current selection after replacement. */
  skipNewSelection?: boolean;
  /** Avoid focusing before inserting replacement text. */
  skipFocus?: boolean;
}

export interface SurroundOptions {
  /** Apply formatting independently across multiple lines. */
  multiline?: boolean;
  /** Put multiline content on lines between the delimiters. */
  useBlockMode?: boolean;
  /** Apply formatting to empty lines. */
  applyEmptyLines?: boolean;
  /** Leave the leading marker outside the restored selection. */
  excludeHeadInSelection?: boolean;
}

export interface AddTextOptions {
  /** Add separating whitespace when adjacent text requires it. */
  ensureSpace?: boolean;
}

export type AutocompleteOptions = Record<string, unknown> | "destroy";

export type UppyFile = MinimalRequiredUppyFile<Meta, Body> & {
  /** Stable identifier used to track the upload placeholder. */
  id: string;
  /** Local file data used to determine placeholder rendering. */
  data: LocalUppyFileNonGhost<Meta, Body>["data"];
};

/**
 * Text operations shared by the plain-text and rich composer editors.
 */
export interface TextManipulation {
  /** Current toolbar-active state. */
  readonly state: ToolbarState & Record<string, unknown>;
  /** Whether this editor supports a rendered preview. */
  readonly allowPreview: boolean;
  /** Upload placeholder operations for this editor. */
  readonly placeholder: PlaceholderHandler;
  /** Autocomplete text operations for this editor. */
  readonly autocompleteHandler: AutocompleteHandler;
  /** Commands contributed by rich-editor extensions. */
  readonly commands?: Record<string, (...args: unknown[]) => unknown>;
  /** Focuses the editor. */
  focus(): void;
  /** Restores focus after a text operation. */
  blurAndFocus(): void;
  /** Indents or outdents the current selection. */
  indentSelection(direction: "left" | "right"): boolean | void;
  /** Configures or destroys autocomplete behavior. */
  autocomplete(options: AutocompleteOptions): unknown;
  /** Reports whether the selection is in code formatting. */
  inCodeBlock(): boolean | Promise<boolean>;
  /** Returns the current editor selection. */
  getSelected(
    trimLeading?: boolean | null | "",
    options?: SelectionOptions
  ): SelectedText;
  /** Selects a text range. */
  selectText(from: number, length: number, options?: SelectTextOptions): void;
  /** Surrounds a supplied selection with formatting text. */
  applySurround(
    selected: SelectedText,
    head: string | ((previous?: string) => string),
    tail: string,
    exampleKey: string,
    options?: SurroundOptions
  ): void;
  /** Applies list-like formatting to a supplied selection. */
  applyList(
    selected: SelectedText,
    head: string | ((previous?: string) => string),
    exampleKey: string,
    options?: SurroundOptions
  ): void;
  /** Applies heading formatting to a supplied selection. */
  applyHeading(
    selected: SelectedText,
    level: number,
    exampleKey?: string
  ): void;
  /** Formats the current selection as code. */
  formatCode(): boolean | void;
  /** Adds text at a supplied selection. */
  addText(selected: SelectedText, text: string, options?: AddTextOptions): void;
  /** Applies a link to the current selection. */
  applyLink(url: string): void;
  /** Toggles the editor's text direction. */
  toggleDirection(): void;
  /** Replaces matching text. */
  replaceText(
    oldValue: string,
    newValue: string,
    options?: ReplaceTextOptions
  ): void;
  /** Handles pasted content. */
  paste(event?: ClipboardEvent): void | Promise<void>;
  /** Inserts a standalone block. */
  insertBlock(block: string): void;
  /** Inserts text at the current selection. */
  insertText(text: string, options?: AddTextOptions): void;
  /** Surrounds the current selection with formatting text. */
  applySurroundSelection(
    head: string | ((previous?: string) => string),
    tail: string,
    exampleKey: string,
    options?: SurroundOptions
  ): void;
  /** Places the cursor at the end of the editor. */
  putCursorAtEnd(): void;
  /** Inserts a selected emoji. */
  emojiSelected(code: string): void;
  /** Wraps the supplied upload placeholders in a grid. */
  autoGridImages(consecutiveImages: string[]): void;
}

/**
 * Upload placeholder operations shared by composer editors.
 */
export interface PlaceholderHandler {
  /** Inserts a placeholder for a file. */
  insert(file: UppyFile): void;
  /** Replaces a completed placeholder with upload markdown. */
  success(file: UppyFile, markdown: string): void;
  /** Cancels every active placeholder. */
  cancelAll(): void;
  /** Cancels one file's placeholder. */
  cancel(file: UppyFile): void;
  /** Marks one placeholder as processing. */
  progress(file: UppyFile): void;
  /** Restores one placeholder after processing. */
  progressComplete(file: UppyFile): void;
}

/**
 * Text and caret operations used by autocomplete.
 */
export interface AutocompleteHandler {
  /** Replaces an autocomplete term in the current text block. */
  replaceTerm(start: number, end: number, text: string): void;
  /** Returns the caret position within the current text block. */
  getCaretPosition(): number;
  /** Reports whether the caret is in code formatting. */
  inCodeBlock(): Promise<boolean>;
  /** Returns caret coordinates relative to the editor. */
  getCaretCoords(caretPosition: number): { top: number; left: number };
  /** Returns the text used for autocomplete matching. */
  getValue(): string;
  /** Reports whether the caret is within a link. */
  inLink?(): Promise<boolean>;
}

// These runtime exports are retained for compatibility with existing consumers.
export const TextManipulation = {};
export const PlaceholderHandler = {};
export const AutocompleteHandler = {};
