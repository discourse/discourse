import { javascriptLanguage } from "@codemirror/lang-javascript";
import { LanguageSupport, LRLanguage } from "@codemirror/language";
import { parseMixed } from "@lezer/common";
import { styleTags, tags as t } from "@lezer/highlight";
import { parser } from "./expression";
import {
  CloseExpression,
  Expression,
  OpenExpression,
} from "./expression.terms";

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
      let from = node.from;
      let to = node.to;

      const first = node.node.firstChild;
      if (first?.type.id === OpenExpression) {
        from = first.to;
      }
      const last = node.node.lastChild;
      if (last?.type.id === CloseExpression) {
        to = last.from;
      }

      if (from >= to) {
        return null;
      }
      return {
        parser: javascriptLanguage.parser,
        overlay: [{ from, to }],
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
