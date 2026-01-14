import { ajax } from "discourse/lib/ajax";

let searchAliasesPromise;

export default async function loadEmojiSearchAliases() {
  searchAliasesPromise ??= ajax("/emojis/search-aliases.json");
  return await searchAliasesPromise;
}
