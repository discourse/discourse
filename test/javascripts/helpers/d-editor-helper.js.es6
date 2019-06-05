export default function formatTextWithSelection(text, [start, len]) {
  return [
    '"',
    text.substr(0, start),
    "<",
    text.substr(start, len),
    ">",
    text.substr(start + len),
    '"'
  ].join("");
}
