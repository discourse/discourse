import { HighlightStyle, syntaxHighlighting } from "@codemirror/language";
import { tags as t } from "@lezer/highlight";

// Classes rather than inline styles, so the palette lives in the stylesheet
// and follows the colour scheme.
const HIGHLIGHT_STYLE = HighlightStyle.define([
  { tag: [t.keyword, t.moduleKeyword], class: "cm-hl-keyword" },
  { tag: [t.controlKeyword, t.operatorKeyword], class: "cm-hl-control" },
  { tag: [t.name, t.variableName], class: "cm-hl-name" },
  { tag: [t.propertyName, t.attributeName], class: "cm-hl-property" },
  {
    tag: [t.function(t.variableName), t.function(t.propertyName)],
    class: "cm-hl-function",
  },
  { tag: [t.typeName, t.className, t.namespace], class: "cm-hl-type" },
  { tag: [t.tagName], class: "cm-hl-tag" },
  { tag: [t.string, t.special(t.string)], class: "cm-hl-string" },
  { tag: [t.number], class: "cm-hl-number" },
  { tag: [t.bool, t.null, t.atom], class: "cm-hl-atom" },
  { tag: [t.comment, t.lineComment, t.blockComment], class: "cm-hl-comment" },
  { tag: [t.operator, t.punctuation, t.separator], class: "cm-hl-punctuation" },
  { tag: [t.bracket, t.brace, t.paren], class: "cm-hl-bracket" },
  { tag: [t.meta, t.processingInstruction], class: "cm-hl-meta" },
  { tag: [t.link, t.url], class: "cm-hl-link" },
  { tag: [t.invalid], class: "cm-hl-invalid" },
  { tag: [t.heading], class: "cm-hl-heading" },
  { tag: [t.emphasis], class: "cm-hl-emphasis" },
  { tag: [t.strong], class: "cm-hl-strong" },
]);

export function defaultHighlighting() {
  return syntaxHighlighting(HIGHLIGHT_STYLE);
}
