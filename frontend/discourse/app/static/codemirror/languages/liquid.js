import { html } from "@codemirror/lang-html";
import { LanguageSupport, StreamLanguage } from "@codemirror/language";
import { Prec } from "@codemirror/state";
import { liquidCompletionSource } from "../lang-liquid/completions.js";
import { liquidDelimiters } from "../lang-liquid/delimiters.js";
import {
  LIQUID_COMMENT,
  liquidOver,
  liquidStatementComments,
} from "../lang-liquid/index.js";

const htmlBase = html();

const BASES = {
  html: new LanguageSupport(htmlBase.language, [
    htmlBase.support,
    Prec.high(htmlBase.language.data.of({ commentTokens: LIQUID_COMMENT })),
  ]),
  text: new LanguageSupport(
    StreamLanguage.define({
      name: "text",
      token(stream) {
        stream.skipToEnd();
        return null;
      },
      languageData: { commentTokens: LIQUID_COMMENT },
    })
  ),
};

const LANGUAGES = {
  html: liquidOver(BASES.html.language),
  text: liquidOver(BASES.text.language),
};

/** @param {import("discourse/lib/liquid-language").LiquidOptions} [options] */
export default function liquidLanguage(cmParams, options) {
  const base = options?.base === "text" ? "text" : "html";
  const language = LANGUAGES[base];

  return new LanguageSupport(language, [
    BASES[base].support,
    language.data.of({
      autocomplete: liquidCompletionSource(options ?? {}),
      commentTokens: LIQUID_COMMENT,
      closeBrackets: { brackets: ["(", "[", "'", '"'] },
    }),
    liquidStatementComments,
    liquidDelimiters,
  ]);
}
