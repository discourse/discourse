import { getAbsoluteURL } from "discourse/lib/get-url";

export default function getFlagContentUrl(flagModel) {
  const url = flagModel.urlWithNumber || flagModel.url;
  return url ? getAbsoluteURL(url) : "";
}
