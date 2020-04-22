const _warned = {};
const NO_RESULT = [false, null];

export default class LinkLookup {
  constructor(links) {
    this._links = links;
  }

  check(post, href) {
    if (_warned[href]) {
      return NO_RESULT;
    }

    const normalized = href.replace(/^https?:\/\//, "").replace(/\/$/, "");
    if (_warned[normalized]) {
      return NO_RESULT;
    }

    const linkInfo = this._links[normalized];
    if (linkInfo) {
      if (post) {
        // Skip edits to the OP
        if (post) {
          const postNumber = post.get("post_number");
          if (postNumber === 1 || postNumber === linkInfo.post_number) {
            return NO_RESULT;
          }
        }

        // Don't warn on older posts
        const createdAt = moment(post.get("created_at"));
        if (createdAt.isBefore(moment().subtract(2, "weeks"))) {
          return NO_RESULT;
        }
      }

      _warned[href] = true;
      _warned[normalized] = true;
      return [true, linkInfo];
    }

    return NO_RESULT;
  }
}
