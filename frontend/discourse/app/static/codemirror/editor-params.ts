import * as cmAutocomplete from "@codemirror/autocomplete";
import * as cmLanguage from "@codemirror/language";
import * as cmLint from "@codemirror/lint";
import * as cmState from "@codemirror/state";
import * as cmView from "@codemirror/view";
import * as lezerCommon from "@lezer/common";
import * as lezerHighlight from "@lezer/highlight";
import * as lezerLr from "@lezer/lr";
import type { CodeEditorParams } from "discourse/lib/code-editor-languages";
import { expressionUtils } from "./expression-utils.js";

export function buildCodeEditorParams(): CodeEditorParams {
  return {
    cmAutocomplete,
    cmLanguage,
    cmLint,
    cmState,
    cmView,
    lezerCommon,
    lezerHighlight,
    lezerLr,
    utils: expressionUtils,
  };
}
