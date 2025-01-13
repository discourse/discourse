export default function domFromString(string) {
  const template = document.createElement("template");
  string = string.trim();
  template.innerHTML = string;
  return template.content.children;
}
