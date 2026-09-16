/** Plain text for names and whitespace-aware presence checks, never rendered HTML. */
export function inlineText(value: unknown): string {
  if (typeof value === "string") {
    return value.replace(/\s+/gu, " ").trim();
  }
  if (
    !value ||
    typeof value !== "object" ||
    !("content" in value) ||
    !Array.isArray(value.content)
  ) {
    return "";
  }
  return value.content
    .map((run: unknown) => {
      if (!run || typeof run !== "object" || !("type" in run)) {
        return "";
      }
      if (run.type === "hard_break") {
        return " ";
      }
      return run.type === "text" &&
        "text" in run &&
        typeof run.text === "string"
        ? run.text
        : "";
    })
    .join("")
    .replace(/\s+/gu, " ")
    .trim();
}
