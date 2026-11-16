import { buildParser } from "./expression.js";
import {
  CloseExpression,
  Expression,
  OpenExpression,
} from "./expression.terms.js";

let language;

// `javascript` is the built-in language's builder, which returns a
// LanguageSupport.
export function expressionLanguage(cmParams, javascript) {
  const { LanguageSupport, LRLanguage } = cmParams.cmLanguage;

  language ??= LRLanguage.define({
    name: "expression",
    parser: buildMixedParser(cmParams, javascript(cmParams).language.parser),
    languageData: {
      closeBrackets: { brackets: ["(", "[", "'", '"'] },
      commentTokens: { line: "//" },
    },
  });

  return new LanguageSupport(language);
}

function buildMixedParser(
  { lezerCommon, lezerHighlight, lezerLr },
  javascriptParser
) {
  const { parseMixed } = lezerCommon;
  const { styleTags, tags: t } = lezerHighlight;

  return buildParser(lezerLr.LRParser).configure({
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
          parser: javascriptParser,
          overlay: [{ from, to }],
        };
      }
      return null;
    }),
  });
}
