export default function formatTextWithSelection(text, [start, len]) {
  return [
    '"',
    text.slice(0, start),
    "<",
    text.slice(start, start + len),
    ">",
    text.slice(start + len),
    '"',
  ].join("");
}
