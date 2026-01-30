/**
 * String similarity utilities for fuzzy matching.
 *
 * This module provides functions for computing string similarity using
 * Jaro-Winkler similarity (primary) and Levenshtein distance (legacy).
 * It is used for typo suggestions in validation error messages throughout
 * Discourse.
 *
 * @module discourse/lib/string-similarity
 */

/**
 * Calculates the Levenshtein distance (edit distance) between two strings.
 * The edit distance is the minimum number of single-character edits
 * (insertions, deletions, substitutions) needed to transform one string into another.
 *
 * Uses the classic dynamic programming approach with O(n×m) time and space complexity.
 *
 * @param {string} a - First string.
 * @param {string} b - Second string.
 * @returns {number} The edit distance between the two strings.
 *
 * @example
 * levenshteinDistance("condition", "conditions") // => 1
 * levenshteinDistance("codition", "conditions")  // => 2
 * levenshteinDistance("kitten", "sitting")       // => 3
 */
export function levenshteinDistance(a, b) {
  if (a.length === 0) {
    return b.length;
  }
  if (b.length === 0) {
    return a.length;
  }

  const matrix = [];

  // Initialize the first column
  for (let i = 0; i <= b.length; i++) {
    matrix[i] = [i];
  }

  // Initialize the first row
  for (let j = 0; j <= a.length; j++) {
    matrix[0][j] = j;
  }

  // Fill in the rest of the matrix
  for (let i = 1; i <= b.length; i++) {
    for (let j = 1; j <= a.length; j++) {
      if (b.charAt(i - 1) === a.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1, // substitution
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j] + 1 // deletion
        );
      }
    }
  }

  return matrix[b.length][a.length];
}

/**
 * Calculates Jaro-Winkler similarity between two strings.
 *
 * Returns a score from 0 to 1, where 1 is an exact match. This algorithm
 * gives bonus weight to strings that share a common prefix, making it
 * ideal for detecting typos where someone forgets a suffix (e.g., "DISCOVERY"
 * instead of "DISCOVERY_PAGES").
 *
 * The algorithm works in two steps:
 * 1. Jaro similarity: Measures matching characters and transpositions
 * 2. Winkler modification: Adds bonus for matching prefix (up to 4 chars)
 *
 * @param {string} a - First string.
 * @param {string} b - Second string.
 * @returns {number} Similarity score between 0 and 1.
 *
 * @example
 * jaroWinklerSimilarity("DISCOVERY", "DISCOVERY_PAGES") // ~0.88 (prefix match)
 * jaroWinklerSimilarity("condition", "conditions")      // ~0.97 (1 char diff)
 * jaroWinklerSimilarity("foobar", "HOMEPAGE")           // ~0.40 (unrelated)
 */
export function jaroWinklerSimilarity(a, b) {
  if (a === b) {
    return 1;
  }
  if (a.length === 0 || b.length === 0) {
    return 0;
  }

  // Calculate the match window - characters can match if within this distance
  const matchWindow = Math.floor(Math.max(a.length, b.length) / 2) - 1;
  const aMatches = new Array(a.length).fill(false);
  const bMatches = new Array(b.length).fill(false);

  let matches = 0;
  let transpositions = 0;

  // Find matching characters within the match window
  for (let i = 0; i < a.length; i++) {
    const start = Math.max(0, i - matchWindow);
    const end = Math.min(i + matchWindow + 1, b.length);

    for (let j = start; j < end; j++) {
      if (bMatches[j] || a[i] !== b[j]) {
        continue;
      }
      aMatches[i] = true;
      bMatches[j] = true;
      matches++;
      break;
    }
  }

  if (matches === 0) {
    return 0;
  }

  // Count transpositions (matched chars that appear in different order)
  let k = 0;
  for (let i = 0; i < a.length; i++) {
    if (!aMatches[i]) {
      continue;
    }
    while (!bMatches[k]) {
      k++;
    }
    if (a[i] !== b[k]) {
      transpositions++;
    }
    k++;
  }

  // Calculate Jaro similarity
  const jaro =
    (matches / a.length +
      matches / b.length +
      (matches - transpositions / 2) / matches) /
    3;

  // Winkler modification: add bonus for common prefix (up to 4 characters)
  let prefix = 0;
  for (let i = 0; i < Math.min(4, a.length, b.length); i++) {
    if (a[i] === b[i]) {
      prefix++;
    } else {
      break;
    }
  }

  return jaro + prefix * 0.1 * (1 - jaro);
}

/**
 * Finds the closest match for a string from a list of candidates.
 *
 * Uses Jaro-Winkler similarity with a threshold to avoid suggesting
 * completely unrelated strings. The Jaro-Winkler algorithm gives bonus
 * weight to strings with matching prefixes, making it ideal for detecting
 * typos like "DISCOVERY" instead of "DISCOVERY_PAGES".
 *
 * @param {string} input - The string to find a match for.
 * @param {readonly string[]} candidates - List of valid strings to match against.
 * @param {Object} [options] - Options.
 * @param {number} [options.minSimilarity=0.8] - Minimum similarity (0-1) to consider a match.
 * @param {boolean} [options.caseSensitive=false] - Whether to compare case-sensitively.
 * @returns {string|null} The closest matching string, or null if none is similar enough.
 *
 * @example
 * findClosestMatch("conditon", ["block", "args", "conditions"]) // => "conditions"
 * findClosestMatch("DISCOVERY", ["DISCOVERY_PAGES", "HOMEPAGE"]) // => "DISCOVERY_PAGES"
 * findClosestMatch("foo", ["block", "args", "conditions"])      // => null
 */
export function findClosestMatch(input, candidates, options = {}) {
  const { minSimilarity = 0.8, caseSensitive = false } = options;
  let closestMatch = null;
  let highestSimilarity = 0;

  const normalizedInput = caseSensitive ? input : input.toLowerCase();

  for (const candidate of candidates) {
    const normalizedCandidate = caseSensitive
      ? candidate
      : candidate.toLowerCase();
    const similarity = jaroWinklerSimilarity(
      normalizedInput,
      normalizedCandidate
    );

    if (similarity > highestSimilarity && similarity >= minSimilarity) {
      highestSimilarity = similarity;
      closestMatch = candidate;
    }
  }

  return closestMatch;
}

/**
 * Formats an unknown value with a "did you mean?" suggestion if a close match exists.
 *
 * @param {string} value - The unknown/invalid value.
 * @param {readonly string[]} validValues - List of valid values to match against.
 * @param {Object} [options] - Options passed to findClosestMatch.
 * @returns {string} Formatted string like '"foo" (did you mean "bar"?)' or just '"foo"'.
 *
 * @example
 * formatWithSuggestion("conditon", ["conditions"]) // => '"conditon" (did you mean "conditions"?)'
 * formatWithSuggestion("xyz", ["conditions"])      // => '"xyz"'
 */
export function formatWithSuggestion(value, validValues, options = {}) {
  const suggestion = findClosestMatch(value, validValues, options);
  if (suggestion) {
    return `"${value}" (did you mean "${suggestion}"?)`;
  }
  return `"${value}"`;
}
