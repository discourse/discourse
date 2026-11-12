export function buildTheme({ cmLanguage, lezerHighlight }) {
  const { HighlightStyle, syntaxHighlighting } = cmLanguage;
  const { tags } = lezerHighlight;

  return syntaxHighlighting(
    HighlightStyle.define([
      { tag: tags.content, class: "cm-wf-text" },
      { tag: tags.brace, class: "cm-wf-brace" },
      { tag: tags.keyword, class: "cm-wf-keyword" },
      { tag: tags.string, class: "cm-wf-string" },
      { tag: tags.number, class: "cm-wf-number" },
      { tag: tags.bool, class: "cm-wf-bool" },
      { tag: tags.null, class: "cm-wf-null" },
      { tag: tags.variableName, class: "cm-wf-variable" },
      { tag: tags.propertyName, class: "cm-wf-property" },
      { tag: tags.function(tags.variableName), class: "cm-wf-function" },
      { tag: tags.function(tags.propertyName), class: "cm-wf-function" },
      { tag: tags.operator, class: "cm-wf-operator" },
      { tag: tags.punctuation, class: "cm-wf-punctuation" },
      { tag: tags.comment, class: "cm-wf-comment" },
    ])
  );
}
