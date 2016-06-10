const _warned = {};

const NO_RESULT = [false, null];

export default class LinkLookup {

  constructor(links) {
    this._links = links;
  }

  check(post, href) {
    if (_warned[href]) { return NO_RESULT; }

    const normalized = href.replace(/^https?:\/\//, '').replace(/\/$/, '');
    if (_warned[normalized]) { return NO_RESULT; }

    const linkInfo = this._links[normalized];
    if (linkInfo) {
      // Skip edits to the same post
      if (post && post.get('post_number') === linkInfo.post_number) { return NO_RESULT; }

      _warned[href] = true;
      _warned[normalized] = true;
      return [true, linkInfo];
    }

    return NO_RESULT;
  }
};
