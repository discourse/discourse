// A valueless flag (`?widget`) arrives as an empty string, which is the
// spelling a hand-written link is most likely to use, while an explicit
// `?widget=false` has to keep reading as absent.
export default function urlFlagSet(value) {
  return value === "" || value === true || value === "true" || value === "1";
}
