import { i18n } from "discourse-i18n";

export const ILLEGAL_CONTENT = "DECISION_GROUND_ILLEGAL_CONTENT";
export const OTHER_KEYWORD = "KEYWORD_OTHER";

// Translation keys are the DSA codes lowercased, so a key is never named "other" —
// a lone "other" key reads as a pluralized string to the locale linter.
export function dsaLegalBasisLabel(code) {
  return i18n(`review.dsa.legal_basis.${code.toLowerCase()}`);
}

export function dsaCategoryLabel(code) {
  return i18n(`review.dsa.categories.${code.toLowerCase()}`);
}

export function dsaKeywordLabel(code) {
  return i18n(`review.dsa.keywords.${code.toLowerCase()}`);
}

/**
 * Builds a plain-text, human-readable summary of a DSA classification.
 *
 * @param {Object} classification
 * @param {string} classification.legal_basis
 * @param {string} [classification.dsa_category]
 * @param {string} [classification.dsa_subcategory]
 * @param {string} [classification.dsa_subcategory_other]
 * @returns {string}
 */
export function dsaClassificationSummary({
  legal_basis,
  dsa_category,
  dsa_subcategory,
  dsa_subcategory_other,
}) {
  const parts = [dsaLegalBasisLabel(legal_basis)];

  if (legal_basis === ILLEGAL_CONTENT && dsa_category) {
    parts.push(dsaCategoryLabel(dsa_category));
  }

  if (dsa_subcategory === OTHER_KEYWORD && dsa_subcategory_other) {
    parts.push(dsa_subcategory_other);
  } else if (dsa_subcategory) {
    parts.push(dsaKeywordLabel(dsa_subcategory));
  }

  return parts.join(" › ");
}
