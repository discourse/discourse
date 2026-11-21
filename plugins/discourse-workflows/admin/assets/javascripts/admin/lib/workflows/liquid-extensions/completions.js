import { i18n } from "discourse-i18n";
import {
  LIQUID_FILTERS,
  LIQUID_TAGS,
} from "discourse/plugins/discourse-workflows/discourse/lib/liquid-syntax";
import { walkScope } from "../expression-context.js";
import { analyzeLiquidAt, loopBindingsAt } from "../liquid-context.js";

// Surfaced first, since they are what a template is usually built around.
const BOOSTED_ROOTS = { item: 10, items: 10, item_index: 5 };

function valueDetail(value) {
  if (Array.isArray(value)) {
    return "array";
  }
  if (value === null) {
    return "null";
  }
  return typeof value;
}

function scopeOptions(target, { section, boost }) {
  return Object.keys(target).map((name) => {
    const value = target[name];
    const isContainer = typeof value === "object" && value !== null;

    return {
      label: name,
      apply: isContainer && !Array.isArray(value) ? `${name}.` : name,
      type: isContainer ? "property" : "variable",
      detail: valueDetail(value),
      boost: boost?.(name),
      section: section(name),
    };
  });
}

/** The completion source behind the Liquid editor; `scope` is read per request. */
export function liquidCompletionSource({ scope, sections }) {
  const tagOptions = LIQUID_TAGS.map(([label, detail]) => ({
    label,
    apply: detail ? `${label} ` : label,
    type: "keyword",
    detail,
    section: sections.tags,
  }));

  const filterOptions = LIQUID_FILTERS.map(([label, detail]) => ({
    label,
    type: "function",
    detail,
    section: sections.filters,
  }));

  return (context) => {
    const text = context.state.doc.toString();
    const analysis = analyzeLiquidAt(text, context.pos);
    if (!analysis) {
      return null;
    }

    if (analysis.kind === "tagName") {
      return { from: analysis.from, options: tagOptions, filter: true };
    }

    if (analysis.kind === "filter") {
      return { from: analysis.from, options: filterOptions, filter: true };
    }

    const currentScope = scope();
    const localScope = {
      ...currentScope,
      ...loopBindingsAt(currentScope, text, context.pos),
    };

    if (analysis.kind === "property") {
      const target = walkScope(localScope, analysis.object);
      if (!target || typeof target !== "object") {
        return null;
      }
      return {
        from: analysis.from,
        options: scopeOptions(target, { section: () => sections.properties }),
        filter: true,
        validFor: /^[\w-]*$/,
      };
    }

    if (!analysis.partial && !context.explicit) {
      return null;
    }

    return {
      from: analysis.from,
      options: scopeOptions(localScope, {
        section: (name) =>
          BOOSTED_ROOTS[name] ? sections.recommended : sections.metadata,
        boost: (name) => BOOSTED_ROOTS[name],
      }),
      filter: true,
    };
  };
}

export function buildLiquidCompletions({ cmAutocomplete, utils }, { scope }) {
  const sections = {
    ...utils.sections,
    tags: utils.section(
      i18n("discourse_workflows.liquid_docs.sections.tags"),
      1
    ),
    filters: utils.section(
      i18n("discourse_workflows.liquid_docs.sections.filters"),
      1
    ),
  };

  return cmAutocomplete.autocompletion({
    override: [liquidCompletionSource({ scope, sections })],
    // Re-open after picking a container, whose applied text ends with ".".
    activateOnCompletion: (completion) =>
      completion.apply?.toString().endsWith("."),
  });
}
