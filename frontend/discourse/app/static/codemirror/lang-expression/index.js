import { javascriptLanguage } from "@codemirror/lang-javascript";
import { LanguageSupport, LRLanguage } from "@codemirror/language";
import { parseMixed } from "@lezer/common";
import { styleTags, tags as t } from "@lezer/highlight";
import { parser } from "./expression";

// Node type id from the compiled grammar (expression.terms.js)
const Expression = 3;

const mixedParser = parser.configure({
  props: [
    styleTags({
      Text: t.content,
      Expression: t.string,
      "OpenExpression CloseExpression": t.brace,
    }),
  ],
  wrap: parseMixed((node) => {
    if (node.type.id === Expression) {
      return {
        parser: javascriptLanguage.parser,
        // offset past the {{ and before }}
        overlay: [{ from: node.from + 2, to: node.to - 2 }],
      };
    }
    return null;
  }),
});

const expressionLang = LRLanguage.define({
  name: "expression",
  parser: mixedParser,
  languageData: {
    closeBrackets: { brackets: ["(", "[", "'", '"'] },
    commentTokens: { line: "//" },
  },
});

export function expressionLanguage() {
  return new LanguageSupport(expressionLang);
}
