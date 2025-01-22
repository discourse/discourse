import { applyValueTransformer } from "discourse/lib/transformer";
import { userPath } from "discourse/lib/url";

export function smallUserAttrs(user) {
  const defaultAttrs = {
    template: user.avatar_template,
    username: user.username,
    post_url: user.post_url,
    url: userPath(user.username_lower),
    unknown: user.unknown,
  };

  return applyValueTransformer("small-user-attrs", defaultAttrs, {
    user,
  });
}
