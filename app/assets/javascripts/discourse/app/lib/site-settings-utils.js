const ACRONYMS = new Set([
  "acl",
  "ai",
  "api",
  "bg",
  "cdn",
  "cors",
  "cta",
  "dm",
  "eu",
  "faq",
  "fg",
  "ga",
  "gb",
  "gtm",
  "hd",
  "http",
  "https",
  "iam",
  "id",
  "imap",
  "ip",
  "jpg",
  "json",
  "kb",
  "mb",
  "oidc",
  "pm",
  "png",
  "pop3",
  "s3",
  "smtp",
  "svg",
  "tl",
  "tl0",
  "tl1",
  "tl2",
  "tl3",
  "tl4",
  "tld",
  "txt",
  "url",
  "ux",
]);

const MIXED_CASE = [
  ["adobe analytics", "Adobe Analytics"],
  ["android", "Android"],
  ["chinese", "Chinese"],
  ["discord", "Discord"],
  ["discourse", "Discourse"],
  ["discourse connect", "Discourse Connect"],
  ["discourse discover", "Discourse Discover"],
  ["discourse narrative bot", "Discourse Narrative Bot"],
  ["facebook", "Facebook"],
  ["github", "GitHub"],
  ["google", "Google"],
  ["gravatar", "Gravatar"],
  ["gravatars", "Gravatars"],
  ["ios", "iOS"],
  ["japanese", "Japanese"],
  ["linkedin", "LinkedIn"],
  ["oauth2", "OAuth2"],
  ["opengraph", "OpenGraph"],
  ["powered by discourse", "Powered by Discourse"],
  ["tiktok", "TikTok"],
  ["tos", "ToS"],
  ["twitter", "Twitter"],
  ["vimeo", "Vimeo"],
  ["wordpress", "WordPress"],
  ["youtube", "YouTube"],
];

export function humanizedSettingName(settingName, settingLabel) {
  const name = settingLabel || settingName.replace(/\_/g, " ");

  const formattedName = (name.charAt(0).toUpperCase() + name.slice(1))
    .split(" ")
    .map((word) =>
      ACRONYMS.has(word.toLowerCase()) ? word.toUpperCase() : word
    )
    .map((word) => {
      if (word.endsWith("s")) {
        const singular = word.slice(0, -1).toLowerCase();
        return ACRONYMS.has(singular) ? singular.toUpperCase() + "s" : word;
      }
      return word;
    })
    .join(" ");

  return MIXED_CASE.reduce(
    (acc, [key, value]) =>
      acc.replaceAll(new RegExp(`\\b${key}\\b`, "gi"), value),
    formattedName
  );
}
