import { ajax } from "discourse/lib/ajax";

let searchAliases;

export default async function loadEmojiSearchAliases() {
  searchAliases ??= await ajax("/emojis/search-aliases");
  return searchAliases;
}
