import { walkScope } from "../expression-context";
import {
  analyzeLiquidAt,
  LIQUID_FILTERS,
  LIQUID_TAGS,
  loopBindingsAt,
} from "../liquid-context";

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

function optionsForObject(target, sections) {
  return Object.keys(target).map((name) => {
    const value = target[name];
    const isContainer = typeof value === "object" && value !== null;

    return {
      label: name,
      // Objects re-open completion at the next level; arrays and scalars end
      // the path, so they insert as-is.
      apply: isContainer && !Array.isArray(value) ? `${name}.` : name,
      type: isContainer ? "property" : "variable",
      detail: valueDetail(value),
      section: sections.properties,
    };
  });
}

/**
 * The completion source backing the Liquid editor. Reads only the document
 * text and cursor, so what it offers can be checked without an editor.
 *
 * `scope` may be a function, for a render context that changes while the
 * editor stays mounted.
 */
export function liquidCompletionSource({ scope, sections }) {
  const resolveScope = typeof scope === "function" ? scope : () => scope;
  const tagOptions = LIQUID_TAGS.map(([label, detail]) => ({
    label,
    apply: `${label} `,
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

    const currentScope = resolveScope();
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
        options: optionsForObject(target, sections),
        filter: true,
        validFor: /^[\w-]*$/,
      };
    }

    if (!analysis.partial && !context.explicit) {
      return null;
    }

    return {
      from: analysis.from,
      options: Object.keys(localScope).map((name) => {
        const value = localScope[name];
        const isObject = typeof value === "object" && value !== null;

        return {
          label: name,
          apply: isObject && !Array.isArray(value) ? `${name}.` : name,
          type: isObject ? "property" : "variable",
          detail: valueDetail(value),
          boost: BOOSTED_ROOTS[name],
          section: BOOSTED_ROOTS[name]
            ? sections.recommended
            : sections.metadata,
        };
      }),
      filter: true,
    };
  };
}

export function buildLiquidCompletions(
  { cmAutocomplete, cmView },
  { scope, sections }
) {
  const { autocompletion, completionKeymap } = cmAutocomplete;
  const { keymap } = cmView;

  return [
    autocompletion({
      override: [liquidCompletionSource({ scope, sections })],
      activateOnTyping: true,
      // Re-open after picking a container, whose applied text ends with ".".
      activateOnCompletion: (completion) =>
        completion.apply?.toString().endsWith("."),
      icons: true,
    }),
    keymap.of(completionKeymap),
  ];
}
