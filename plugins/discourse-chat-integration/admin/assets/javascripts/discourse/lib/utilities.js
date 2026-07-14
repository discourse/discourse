export default function getTagName(tag) {
  return typeof tag === "string" ? tag : tag.name;
}

export const PROVIDER_LEARN_MORE_URLS = {
  discord: "https://meta.discourse.org/t/-/66600",
  gitter: "https://meta.discourse.org/t/-/69220",
  google: "https://meta.discourse.org/t/-/177362",
  mattermost: "https://meta.discourse.org/t/-/66811",
  matrix: "https://meta.discourse.org/t/-/66944",
  rocketchat: "https://meta.discourse.org/t/-/68633",
  slack: "https://meta.discourse.org/t/-/66730",
  teams: "https://meta.discourse.org/t/-/159193",
  telegram: "https://meta.discourse.org/t/-/66603",
  webex: "https://meta.discourse.org/t/-/173026",
  zulip: "https://meta.discourse.org/t/-/68501",
};
