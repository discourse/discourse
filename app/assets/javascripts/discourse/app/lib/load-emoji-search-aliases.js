import { ajax } from "discourse/lib/ajax";

let searchAliasesPromise;

export default async function loadEmojiSearchAliases() {
  searchAliasesPromise ??= ajax("/emojis/search-aliases");
  return await searchAliasesPromise;
}
