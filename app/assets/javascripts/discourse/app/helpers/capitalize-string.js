import deprecated from "discourse/lib/deprecated";

export default function capitalizeString(str) {
  deprecated("capitalize-string helper is deprecated", {
    id: "discourse.capitalize-string",
    since: "3.1.0.beta6",
  });
  return str[0].toUpperCase() + str.slice(1);
}
