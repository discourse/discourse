import deprecated from "discourse/lib/deprecated";
import actualGetUrl from "discourse/lib/get-url";

export default function getUrl(value) {
  deprecated(
    "Importing from 'discourse/helpers/get-url' is deprecated. Use 'discourse/lib/get-url' instead.",
    {
      id: "discourse.get-url-helper",
      since: "3.5.0.beta8-dev",
    }
  );
  return actualGetUrl(value);
}
