import * as cmAutocomplete from "@codemirror/autocomplete";
import * as cmLanguage from "@codemirror/language";
import * as cmState from "@codemirror/state";
import * as cmView from "@codemirror/view";
import * as lezerHighlight from "@lezer/highlight";
import type { CodeEditorParams } from "discourse/lib/code-editor-languages";

let expressionUtils: CodeEditorParams["utils"];

export async function loadExpressionUtils() {
  expressionUtils ??= (await import("./expression-utils.js")).expressionUtils;
}

export function buildCodeEditorParams(): CodeEditorParams {
  return {
    cmAutocomplete,
    cmLanguage,
    cmState,
    cmView,
    lezerHighlight,
    utils: expressionUtils,
  };
}
