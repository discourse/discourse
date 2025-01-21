import { helperContext } from "discourse/lib/helpers";

export function prioritizeNameInUx(name) {
  let siteSettings = helperContext().siteSettings;

  return (
    !siteSettings.prioritize_username_in_ux && name && name.trim().length > 0
  );
}

export function prioritizeNameFallback(name, username) {
  let siteSettings = helperContext().siteSettings;
  if (
    siteSettings.display_name_on_posts &&
    !siteSettings.prioritize_username_in_ux
  ) {
    return name || username;
  } else {
    return username;
  }
}

export function emojiBasePath() {
  let siteSettings = helperContext().siteSettings;

  return siteSettings.external_emoji_url === ""
    ? "/images/emoji"
    : siteSettings.external_emoji_url;
}
