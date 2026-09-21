import { sass } from "@codemirror/lang-sass";

export default function scssLanguage(cmParams, options = {}) {
  return sass({ indented: false, ...options });
}
