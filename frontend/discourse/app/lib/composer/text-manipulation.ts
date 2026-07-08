import type { Body, Meta, MinimalRequiredUppyFile } from "@uppy/utils";

export interface ToolbarState {
  inBold?: boolean;
  inItalic?: boolean;
  inLink?: boolean;
  inBulletList?: boolean;
  inOrderedList?: boolean;
  inCode?: boolean;
  inCodeBlock?: boolean;
  inBlockquote?: boolean;
  inHeading?: boolean;
  inHeadingLevel?: number;
}

/** Interface for text manipulation with an underlying editor implementation. */
export interface TextManipulation {
  /** The current state of the editor for toolbar button active states */
  readonly state: ToolbarState | undefined;

  /** Whether the editor allows a preview being shown */
  readonly allowPreview: boolean;

  /** The placeholder handler instance */
  readonly placeholder: PlaceholderHandler;

  /** Focuses the editor */
  focus(): void;

  /** Blurs and focuses the editor */
  blurAndFocus(): void;

  /** Indents/un-indents the current selection. direction is either "right" or "left" */
  indentSelection(direction: string): void;

  /** Configures an Autocomplete for the editor */
  autocomplete(options: unknown): void;

  /** Checks if the current selection is in a code block */
  inCodeBlock(): Promise<boolean>;

  /** Gets the current selection */
  getSelected(trimLeading: unknown): unknown;

  /** Selects the text from the given range */
  selectText(from: number, to: number, options?: unknown): void;

  /** Applies the given head/tail to the selected text */
  applySurround(
    selected: string,
    head: string,
    tail: string,
    exampleKey: string,
    opts?: unknown
  ): void;

  /** Applies the list format to the selected text */
  applyList(
    selected: string,
    head: string,
    exampleKey: string,
    opts?: unknown
  ): void;

  /** Formats the current selection as code */
  formatCode(): void;

  /** Adds text */
  addText(selected: string, text: string): void;

  /** Toggles the text (LTR/RTL) direction */
  toggleDirection(): void;

  /** Replaces text */
  replaceText(oldValue: string, newValue: string, opts?: unknown): void;

  /** Handles the paste event */
  paste(event: ClipboardEvent): void;

  /** Inserts the block */
  insertBlock(block: string): void;

  /** Inserts text */
  insertText(text: string): void;

  /** Applies the head/tail to the selected text */
  applySurroundSelection(
    head: string,
    tail: string,
    exampleKey: string,
    opts?: unknown
  ): void;

  /** Puts cursor at the end of the editor */
  putCursorAtEnd(): void;
}

export const TextManipulation = {};

type UppyFile = MinimalRequiredUppyFile<Meta, Body>;

/** Interface for handling placeholders on upload events */
export interface PlaceholderHandler {
  /** Inserts a file */
  insert(file: UppyFile): void;

  /** Success event for file upload */
  success(file: UppyFile, markdown: string): void;

  /** Cancels all uploads */
  cancelAll(): void;

  /** Cancels one uploaded file */
  cancel(file: UppyFile): void;

  /** Progress event */
  progress(file: UppyFile): void;

  /** Progress complete event */
  progressComplete(file: UppyFile): void;
}

export const PlaceholderHandler = {};

/** Interface for the Autocomplete handler */
export interface AutocompleteHandler {
  /** Replaces the range from start to end with the given text */
  replaceTerm(start: number, end: number, text: string): void;

  /** Gets the caret position */
  getCaretPosition(): number;

  /** Checks if the current selection is in a code block */
  inCodeBlock(): Promise<boolean>;

  /** Gets the caret coordinates for the given caret position */
  getCaretCoords(caretPositon: number): { top: number; left: number };

  /** Gets the current value for the autocomplete */
  getValue(): string;
}

export const AutocompleteHandler = {};
