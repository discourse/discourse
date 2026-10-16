import * as cmAutocomplete from "@codemirror/autocomplete";
import * as cmLanguage from "@codemirror/language";
import * as cmState from "@codemirror/state";
import * as cmView from "@codemirror/view";
import * as lezerHighlight from "@lezer/highlight";
import type { CodeEditorParams } from "discourse/lib/code-editor-languages";
import { expressionUtils } from "./expression-utils.js";

export function buildCmParams(): CodeEditorParams {
  return {
    cmAutocomplete,
    cmLanguage,
    cmState,
    cmView,
    lezerHighlight,
    utils: expressionUtils,
  };
}
