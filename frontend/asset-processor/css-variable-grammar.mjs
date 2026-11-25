/**
 * Parses CSS custom property names against the naming scheme:
 * `--{prefix}-{Owner}-{part}-{category}-{property}-{role}-{variant}-{state}`,
 * where every word comes from the vocabulary's closed lists.
 *
 * Returns a function that takes a name and returns `{ errors, notes, layer }`.
 * A name follows the scheme when `errors` is empty. Notes point out new words,
 * such as a part that the vocabulary does not list yet.
 */
export default function createGrammar(vocabulary) {
  const V = vocabularyLists(vocabulary);
  const closedWords = new Set([
    ...V.categories,
    ...V.sizes,
    ...V.steps,
    ...V.strength,
    ...V.weights,
    ...V.condition,
    ...V.interaction,
    ...V.axes,
  ]);
  for (const category of Object.values(V.props)) {
    for (const [property, spec] of Object.entries(category)) {
      if (property) {
        closedWords.add(property);
      }
      spec.roles.forEach((role) => closedWords.add(role));
    }
  }
  for (const properties of Object.values(V.compExtraProps)) {
    properties.forEach((property) => closedWords.add(property));
  }
  const multiWords = new Set([...closedWords].filter((w) => w.includes("-")));

  return (name) => parse(name, V, closedWords, multiWords);
}

const PREFIXES = [
  ["d-sys-", "sys"],
  ["d-comp-", "comp"],
  ["tc-", "tc"],
  ["t-", "t"],
  ["p-", "p"],
];

function vocabularyLists(vocabulary) {
  const props = {};
  const compExtraProps = {};
  for (const [category, definition] of Object.entries(vocabulary.categories)) {
    const normalize = (d) => ({
      roles: d.roles || [],
      variant: d.variant || null,
      extraVariants: d.extraVariants,
      roleOptional: d.roleOptional,
    });
    props[category] = {};
    if (definition.properties) {
      for (const [property, d] of Object.entries(definition.properties)) {
        props[category][property] = normalize(d);
      }
    } else {
      props[category][""] = normalize(definition);
    }
    if (definition.componentProperties) {
      compExtraProps[category] = definition.componentProperties;
    }
  }

  return {
    categories: Object.keys(vocabulary.categories),
    sizes: vocabulary.variants.size,
    steps: vocabulary.variants.step,
    strength: vocabulary.variants.strength,
    weights: vocabulary.variants.weight,
    intents: vocabulary.intents,
    condition: vocabulary.states.condition,
    interaction: vocabulary.states.interaction,
    axes: vocabulary.axes,
    props,
    compExtraProps,
    kinds: vocabulary.kinds || {},
    parts: vocabulary.parts || {},
  };
}

function variantWords(V, kind) {
  return (
    {
      size: V.sizes,
      step: V.steps,
      strength: V.strength,
      weight: V.weights,
    }[kind] || []
  );
}

function parse(name, V, closedWords, multiWords) {
  const out = { errors: [], notes: [], layer: null };
  if (!name.startsWith("--")) {
    out.errors.push("A custom property starts with --.");
    return out;
  }

  let rest = name.slice(2);
  const prefix = PREFIXES.find(([p]) => rest.startsWith(p));
  if (!prefix) {
    out.errors.push(
      rest.startsWith("d-")
        ? "Under --d- only sys and comp are allowed."
        : "Unknown prefix. Use --d-sys-, --d-comp-, --t-, --tc- or --p-."
    );
    return out;
  }
  const layer = prefix[1];
  out.layer = layer;
  rest = rest.slice(prefix[0].length);

  let parts = rest.split("-");
  if (parts.some((part) => part === "")) {
    out.errors.push(
      "Double dash inside the name. Every slot is separated by a single dash."
    );
  }
  parts = parts.filter((part) => part !== "");

  const isPascal = (w) => /^[A-Z][A-Za-z0-9]*$/.test(w);
  const isComponent = layer !== "sys";
  let owner = null;
  let component = null;

  if (isComponent) {
    owner = parts.shift();
    if (!owner || !isPascal(owner)) {
      out.errors.push(
        `The owner after the prefix must be PascalCase${owner ? `, got "${owner}"` : ""}.`
      );
    }
    if (layer !== "comp" && parts[0] && isPascal(parts[0])) {
      component = parts.shift();
    }
  }
  const ownerKey = owner && (component ? `${owner}-${component}` : owner);
  const kinds = (ownerKey && V.kinds[ownerKey]) || [];
  const knownParts = (ownerKey && V.parts[ownerKey]) || [];

  const words = [];
  for (let i = 0; i < parts.length; i++) {
    const two = `${parts[i]}-${parts[i + 1]}`;
    if (multiWords.has(two)) {
      words.push(two);
      i++;
    } else {
      words.push(parts[i]);
    }
  }
  for (const w of words) {
    if (/[A-Z]/.test(w)) {
      out.errors.push(
        `"${w}": only the owner and component are PascalCase; everything after is lowercase.`
      );
    }
  }

  let i = 0;
  if (isComponent && words[i] && !V.categories.includes(words[i])) {
    if (closedWords.has(words[i])) {
      out.errors.push(
        `"${words[i]}" is a vocabulary word and cannot be a part. A category must come first.`
      );
    } else if (!knownParts.includes(words[i])) {
      out.notes.push(
        `"${words[i]}" is a new part of ${ownerKey}. Add it to parts in the vocabulary.`
      );
    }
    i++;
  }

  const category = words[i];
  if (!category) {
    out.errors.push("A category is required (color, font, space, …).");
    return out;
  }
  if (!V.categories.includes(category)) {
    out.errors.push(
      `"${category}" is not a category. Use one of: ${V.categories.join(", ")}.`
    );
    return out;
  }
  i++;

  const categoryProps = V.props[category];
  let spec;
  let property = null;
  if (categoryProps[""]) {
    spec = categoryProps[""];
  } else {
    const w = words[i];
    const extra = isComponent ? V.compExtraProps[category] || [] : [];
    if (w && categoryProps[w]) {
      property = w;
      spec = categoryProps[w];
      i++;
    } else if (w && extra.includes(w)) {
      property = w;
      spec = { roles: [], variant: null };
      i++;
    } else {
      out.errors.push(
        `"${category}" needs a property: ${Object.keys(categoryProps).concat(extra).join(", ")}.`
      );
      return out;
    }
  }

  const isState = (w) => V.condition.includes(w) || V.interaction.includes(w);
  const variants = variantWords(V, spec.variant).concat(
    spec.extraVariants || []
  );
  let role = null;
  let isKind = false;
  let w = words[i];
  if (w && isComponent && category === "space" && V.axes.includes(w)) {
    role = w;
    i++;
  } else if (w && kinds.includes(w)) {
    role = w;
    isKind = true;
    i++;
  } else if (w && spec.roles.includes(w)) {
    role = w;
    i++;
  } else if (
    w &&
    isComponent &&
    !isState(w) &&
    !variants.includes(w) &&
    !V.sizes.includes(w)
  ) {
    out.errors.push(
      kinds.length
        ? `"${w}" is not a kind of ${ownerKey}. Kinds: ${kinds.join(", ")}.`
        : `"${w}" is not a role here, and ${ownerKey || "this component"} has no kinds in the vocabulary.`
    );
    i++;
  }
  if (!role && spec.roles.length && !isComponent && !spec.roleOptional) {
    out.errors.push(`A role is required here: ${spec.roles.join(", ")}.`);
  }

  w = words[i];
  let variant = null;
  if (w && variants.includes(w)) {
    if (spec.variant === "strength" && !(V.intents.includes(role) || isKind)) {
      out.errors.push(
        `Strength "${w}" only follows an intent role (${V.intents.join(", ")}) or a component kind.`
      );
    }
    variant = w;
    i++;
  } else if (w && V.sizes.includes(w) && spec.variant !== "size") {
    out.errors.push(
      spec.variant === "step"
        ? `Spacing counts 4px steps instead of sizes: half, 1 to 12 (so "${w}" is not allowed).`
        : `"${w}" is a size, but ${category}${property ? `-${property}` : ""} has no size scale.`
    );
    i++;
  }
  if (
    !variant &&
    spec.variant &&
    spec.variant !== "strength" &&
    !spec.roles.length &&
    !isComponent
  ) {
    out.errors.push(
      `A ${spec.variant} variant is required: ${variantWords(V, spec.variant).join(", ")}.`
    );
  }

  const states = [];
  for (; i < words.length; i++) {
    w = words[i];
    if (isState(w)) {
      states.push(w);
    } else if (w === "active") {
      out.errors.push(
        `"active" is not allowed. Use pressed, current or selected.`
      );
    } else if (w === "hover" || w === "focus" || w === "press") {
      out.errors.push(`States use the past participle: "${w}ed".`);
    } else if (w === "large" || w === "small" || w === "medium") {
      out.errors.push(`Use the short size words (sm, md, lg), not "${w}".`);
    } else {
      out.errors.push(`"${w}" does not fit any slot at this position.`);
    }
  }
  if (states.length > 2) {
    out.errors.push("At most two states.");
  }
  if (
    states.length === 2 &&
    !(V.condition.includes(states[0]) && V.interaction.includes(states[1]))
  ) {
    out.errors.push(
      "Two states go condition first, interaction second (selected-hovered)."
    );
  }

  return out;
}
