import type { CompletionSection } from "@codemirror/autocomplete";

/** Presentation metadata for a Liquid variable or property completion. */
export interface LiquidCompletionMetadata {
  /** Short description displayed beside the name. */
  detail?: string;
  /** Plain-text explanation or sample shown when selected. */
  info?: string;
  /** Adjustment to the completion's ranking. */
  boost?: number;
  /** Group heading and ordering, using the editor's section descriptor. */
  section?: CompletionSection;
}

/** Renderer-specific configuration for the built-in Liquid language. */
export interface LiquidOptions {
  /** Content surrounding Liquid tags; defaults to HTML. */
  base?: "html" | "text";
  /**
   * Representative render values, or a provider read when completion is computed.
   * Array elements supply their shape; an empty array has no known properties.
   */
  scope?: object | (() => object);
  /** Accepted opening tags; omitted uses standard Liquid, an empty list offers none. */
  tags?: readonly string[];
  /** Accepted filters; omitted uses standard Liquid, an empty list offers none. */
  filters?: readonly string[];
  /**
   * Annotates a completion, hides it with null, or leaves defaults with undefined.
   * Paths refer to the source scope through aliases, with [] for array elements.
   * Values are examples, not evaluated results; unknown values are undefined.
   */
  describe?: (
    path: readonly string[],
    value: unknown,
    context: {
      /** True for a standalone name, false for a property of another value. */
      variable: boolean;
    }
  ) => LiquidCompletionMetadata | null | undefined;
}
