import { registerRawHelper } from "discourse/lib/helpers";

registerRawHelper("shorten-url", shortenUrl);
export default function shortenUrl(url) {
  let matches = url.match(/\//g);

  if (matches && matches.length === 3) {
    url = url.replace(/\/$/, "");
  }
  url = url.replace(/^https?:\/\//, "");
  url = url.replace(/^www\./, "");
  return url.substring(0, 80);
}
