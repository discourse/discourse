// Fuzzy name matches with strength below this (more negative) are order-only
// subsequence matches that are too weak to show, unless the stripped query
// appears as a contiguous block in the stripped name (see isFuzzyNameMatch).
const MIN_FUZZY_NAME_MATCH_STRENGTH = -2;

export default class SiteSettingMatcher {
  constructor(filter, siteSetting) {
    this.filter = filter;
    this.siteSetting = siteSetting;
    this.strippedQuery = filter.replace(/[^a-z0-9]/gi, "");
    this.fuzzyRegex = new RegExp(this.strippedQuery.split("").join(".*"), "i");
    this.fuzzyRegexGaps = new RegExp(
      ".*" + this.strippedQuery.split("").join("(.*)"),
      "i"
    );
    this.matchStrength = 0;
  }

  get isNameMatch() {
    const name = this.siteSetting.setting.toLowerCase();

    return (
      name.includes(this.filter) ||
      name.replace(/_/g, " ").includes(this.filter)
    );
  }

  get isKeywordMatch() {
    return (this.siteSetting.keywords || []).some((keyword) =>
      keyword
        .replace(/_/g, " ")
        .toLowerCase()
        .includes(this.filter.replace(/_/g, " "))
    );
  }

  get isDescriptionMatch() {
    return this.siteSetting.description.toLowerCase().includes(this.filter);
  }

  get isValueMatch() {
    return (this.siteSetting.value || "")
      .toString()
      .toLowerCase()
      .includes(this.filter);
  }

  get isFuzzyNameMatch() {
    const name = this.siteSetting.setting.toLowerCase();

    if (this.strippedQuery.length < 3) {
      return false;
    }

    if (!this.fuzzyRegex.test(name)) {
      return false;
    }

    const fuzzySearchLimiter = 25;
    const strippedSetting = name.replace(/[^a-z0-9]/gi, "");

    if (
      strippedSetting.length >
      this.strippedQuery.length + fuzzySearchLimiter
    ) {
      return false;
    }

    // Contiguous block in the de-punctuated name: keep matchStrength 0 and
    // skip gap scoring (subsequence can still look "weak" for long names).
    if (strippedSetting.includes(this.strippedQuery)) {
      return true;
    }

    const gapResult = strippedSetting.match(this.fuzzyRegexGaps);

    if (gapResult) {
      // Discard empty gaps and disregard the full string match.
      const numberOfGaps = gapResult.filter((gap) => gap !== "").length - 1;

      this.matchStrength -= numberOfGaps;
    }

    // Order-only subsequence: drop very weak matches (e.g. "teams" matched
    // across letters in "…telegram…" in a long `chat_integration_*` name).
    if (this.matchStrength < MIN_FUZZY_NAME_MATCH_STRENGTH) {
      return false;
    }

    return true;
  }
}
