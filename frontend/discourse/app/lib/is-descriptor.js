export default function isDescriptor(item) {
  return (
    item &&
    typeof item === "object" &&
    "writable" in item &&
    "enumerable" in item &&
    "configurable" in item
  );
}
