import type { CompletionSection } from "@codemirror/autocomplete";
import { i18n } from "discourse-i18n";

function renderHeader(section: CompletionSection): HTMLElement {
  const header = document.createElement("div");
  header.className = "cm-completion-section-header";
  header.textContent = section.name;
  return header;
}

/**
 * Builds a completion section whose heading matches the editor's standard
 * sections.
 *
 * @param name - the visible heading; completions sharing a name are grouped
 * @param rank - lower ranks are listed first
 */
export function completionSection(
  name: string,
  rank: number
): CompletionSection {
  return { name, rank, header: renderHeader };
}

/** The sections completions are grouped under across languages. */
export interface StandardCompletionSections {
  recommended: CompletionSection;
  properties: CompletionSection;
  methods: CompletionSection;
  metadata: CompletionSection;
  globals: CompletionSection;
}

/**
 * Builds the standard sections. Rank 1 is left free, so a language can list
 * a section of its own right after the recommended completions.
 */
export function standardCompletionSections(): StandardCompletionSections {
  return {
    recommended: completionSection(
      i18n("code_editor.completion_sections.recommended"),
      0
    ),
    properties: completionSection(
      i18n("code_editor.completion_sections.properties"),
      2
    ),
    methods: completionSection(
      i18n("code_editor.completion_sections.methods"),
      3
    ),
    metadata: completionSection(
      i18n("code_editor.completion_sections.metadata"),
      4
    ),
    globals: completionSection(
      i18n("code_editor.completion_sections.globals"),
      5
    ),
  };
}
