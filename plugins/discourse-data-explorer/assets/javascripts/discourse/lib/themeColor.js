export default function themeColor(name) {
  const style = getComputedStyle(document.body);
  return style.getPropertyValue(name);
}
