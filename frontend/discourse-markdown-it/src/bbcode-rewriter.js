import {
  bbCodeAttributeTokens,
  parseBBCodeTag,
  serializeBBCodeAttr,
} from "./features/bbcode-block.js";

const NAME_PATTERN = /^[a-zA-Z_][a-zA-Z0-9_-]*$/;

/** Find opening tags using the same grammar as the Markdown engine. */
export function scanBBCodeTags(raw, tag) {
  const candidates = [];
  let position = raw.indexOf("[");

  while (position !== -1) {
    const parsed = parseBBCodeTag(raw, position, raw.length);

    if (parsed && !parsed.closing && parsed.tag === tag) {
      candidates.push({
        index: candidates.length,
        start: position,
        length: parsed.length,
        opening: raw.slice(position, position + parsed.length),
      });
    }

    // A tag-looking value inside a valid opening tag is part of that tag.
    position = raw.indexOf("[", position + (parsed?.length || 1));
  }

  return candidates;
}

/** Mark candidates without normalizing their original attributes. */
export function markBBCodeTags(raw, tag, attribute, prefix, onlyIndex = null) {
  if (!NAME_PATTERN.test(attribute) || !/^[a-z0-9]+$/.test(prefix)) {
    throw new Error("Invalid BBCode marker");
  }

  const candidates = scanBBCodeTags(raw, tag);

  for (const candidate of candidates.reverse()) {
    if (onlyIndex !== null && candidate.index !== onlyIndex) {
      continue;
    }

    const opening =
      candidate.opening.slice(0, -1) +
      ` ${attribute}=${prefix}-${candidate.index}]`;
    raw = spliceOpening(raw, candidate, opening);
  }

  return raw;
}

/** Rewrite one previously selected opening tag; null removes an attribute. */
export function rewriteBBCodeTag(raw, tag, index, expectedOpening, changes) {
  const candidate = scanBBCodeTags(raw, tag)[index];

  if (!candidate || candidate.opening !== expectedOpening) {
    throw new Error("BBCode target changed");
  }

  const parsed = parseBBCodeTag(candidate.opening, 0, candidate.opening.length);
  const attributes = new Map(Object.entries(parsed.attrs));

  for (const [name, value] of Object.entries(changes)) {
    if (name !== "_default" && !NAME_PATTERN.test(name)) {
      throw new Error("Invalid BBCode attribute name");
    }

    if (value === null) {
      attributes.delete(name);
    } else if (["string", "number", "boolean"].includes(typeof value)) {
      const text = String(value);
      if (/[\r\n]/.test(text)) {
        throw new Error("BBCode attribute values must stay on one line");
      }
      attributes.set(name, text);
    } else {
      throw new Error("BBCode attribute values must be scalar or null");
    }
  }

  const opening = rewriteOpening(candidate.opening, changes);
  const roundTrip = parseBBCodeTag(opening, 0, opening.length);

  if (
    !roundTrip ||
    roundTrip.tag !== tag ||
    roundTrip.length !== opening.length ||
    !sameAttributes(attributes, roundTrip.attrs)
  ) {
    throw new Error(
      "BBCode attributes cannot be serialized without changing their values"
    );
  }

  return spliceOpening(raw, candidate, opening);
}

function sameAttributes(expected, actual) {
  return (
    expected.size === Object.keys(actual).length &&
    [...expected].every(
      ([name, value]) => Object.hasOwn(actual, name) && actual[name] === value
    )
  );
}

/** Change only requested attributes; leave every other token byte-for-byte intact. */
function rewriteOpening(original, changes) {
  // The default [tag=value] form needs a separate edit operation. Never
  // silently append it as though it were a named attribute.
  if (Object.hasOwn(changes, "_default")) {
    throw new Error("Rewriting default BBCode attributes is not supported");
  }

  const { headEnd, attributes } = bbCodeAttributeTokens(original);
  const head = original.slice(0, headEnd);
  let result = head;
  let cursor = headEnd;

  for (const { name, start, end } of attributes) {
    if (!Object.hasOwn(changes, name)) {
      const separator = original.slice(cursor, start);
      // Removing the first attribute can expose an adjacent bare flag.
      // Keep it separate from the opening tag name: [event s], not [events].
      result += separator || (result === head ? " " : "");
      result += original.slice(start, end);
    }
    cursor = end;
  }

  // Preserve pre-] whitespace, then append the requested attributes.
  result += original.slice(cursor, -1);
  for (const [name, value] of Object.entries(changes)) {
    if (value !== null) {
      result +=
        value === "" ? ` ${name}` : serializeBBCodeAttr(String(value), name);
    }
  }

  return `${result}]`;
}

function spliceOpening(raw, candidate, opening) {
  return (
    raw.slice(0, candidate.start) +
    opening +
    raw.slice(candidate.start + candidate.length)
  );
}
