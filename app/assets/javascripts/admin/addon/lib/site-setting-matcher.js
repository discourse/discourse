export default class SiteSettingMatcher {
  constructor(filter, siteSetting) {
    this.filter = filter;
    this.siteSetting = siteSetting;
    this.strippedQuery = filter.replace(/[^a-z0-9]/gi, "");
    this.fuzzyRegex = new RegExp(this.strippedQuery.split("").join(".*"), "i");
    this.fuzzyRegexGaps = new RegExp(
      this.strippedQuery.split("").join("(.*)"),
      "i"
    );
    this.matchStrength = 0;
  }

  get isNameMatch() {
    const name = this.siteSetting.get("setting").toLowerCase();

    return (
      name.includes(this.filter) ||
      name.replace(/_/g, " ").includes(this.filter)
    );
  }

  get isKeywordMatch() {
    (this.siteSetting.get("keywords") || []).any((keyword) =>
      keyword
        .replace(/_/g, " ")
        .toLowerCase()
        .includes(this.filter.replace(/_/g, " "))
    );
  }

  get isDescriptionMatch() {
    return this.siteSetting
      .get("description")
      .toLowerCase()
      .includes(this.filter);
  }

  get isValueMatch() {
    (this.siteSetting.get("value") || "")
      .toString()
      .toLowerCase()
      .includes(this.filter);
  }

  get isFuzzyNameMatch() {
    const name = this.siteSetting.get("setting").toLowerCase();

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

    const gapResult = strippedSetting.match(this.fuzzyRegexGaps);

    if (gapResult) {
      this.matchStrength -= gapResult.filter((gap) => gap !== "").length;
    }

    return true;
  }
}
