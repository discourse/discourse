/**
 * String similarity utilities for fuzzy matching.
 *
 * This module provides functions for computing string similarity using
 * Levenshtein distance (edit distance). It is used for typo suggestions
 * in validation error messages throughout Discourse.
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
 * Finds the closest match for a string from a list of candidates.
 * Uses Levenshtein distance with a threshold to avoid suggesting
 * completely unrelated strings.
 *
 * @param {string} input - The string to find a match for.
 * @param {Array<string>} candidates - List of valid strings to match against.
 * @param {Object} [options] - Options.
 * @param {number} [options.maxDistance=3] - Maximum edit distance to consider a match.
 * @param {boolean} [options.caseSensitive=false] - Whether to compare case-sensitively.
 * @returns {string|null} The closest matching string, or null if none is close enough.
 *
 * @example
 * findClosestMatch("conditon", ["block", "args", "conditions"]) // => "conditions"
 * findClosestMatch("foo", ["block", "args", "conditions"])      // => null
 */
export function findClosestMatch(input, candidates, options = {}) {
  const { maxDistance = 3, caseSensitive = false } = options;
  let closestMatch = null;
  let closestDistance = Infinity;

  const normalizedInput = caseSensitive ? input : input.toLowerCase();

  for (const candidate of candidates) {
    const normalizedCandidate = caseSensitive
      ? candidate
      : candidate.toLowerCase();
    const distance = levenshteinDistance(normalizedInput, normalizedCandidate);
    if (distance < closestDistance && distance <= maxDistance) {
      closestDistance = distance;
      closestMatch = candidate;
    }
  }

  return closestMatch;
}

/**
 * Formats an unknown value with a "did you mean?" suggestion if a close match exists.
 *
 * @param {string} value - The unknown/invalid value.
 * @param {Array<string>} validValues - List of valid values to match against.
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
