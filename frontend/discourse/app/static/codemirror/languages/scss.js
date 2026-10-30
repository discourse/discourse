import { sass } from "@codemirror/lang-sass";

export default function scssLanguage() {
  return sass({ indented: false });
}
