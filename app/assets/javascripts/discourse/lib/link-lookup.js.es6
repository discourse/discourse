const _warned = {};

export default class LinkLookup {

  constructor(links) {
    this._links = links;
  }

  check(href) {
    if (_warned[href]) { return [false, null]; }

    const normalized = href.replace(/^https?:\/\//, '');
    if (_warned[normalized]) { return [false, null]; }

    const linkInfo = this._links[normalized];
    if (linkInfo) {
      _warned[href] = true;
      _warned[normalized] = true;
      return [true, linkInfo];
    }

    return [false, null];
  }
};
