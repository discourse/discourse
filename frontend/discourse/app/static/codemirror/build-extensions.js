import * as cmAutocomplete from "@codemirror/autocomplete";
import * as cmLanguage from "@codemirror/language";
import * as cmState from "@codemirror/state";
import * as cmView from "@codemirror/view";
import * as lezerHighlight from "@lezer/highlight";
import { expressionUtils } from "./expression-utils";

export function buildCmParams() {
  return {
    cmAutocomplete,
    cmLanguage,
    cmState,
    cmView,
    lezerHighlight,
    utils: expressionUtils,
  };
}
