import { i18n } from "discourse-i18n";
import { buildTheme } from "../expression-extensions/theme";
import { buildLiquidScope } from "../liquid-context";
import { buildAutoCloseDelimiters } from "./auto-close-delimiters";
import { buildLiquidCompletions } from "./completions";
import { buildLiquidDragDrop } from "./drag-drop";

export default function buildLiquidExtensions(cmParams, domainOpts = {}) {
  const sections = {
    ...cmParams.utils.sections,
    tags: cmParams.utils.section(
      i18n("discourse_workflows.liquid_docs.sections.tags"),
      1
    ),
    filters: cmParams.utils.section(
      i18n("discourse_workflows.liquid_docs.sections.filters"),
      1
    ),
  };

  // The run mode is read on every use rather than captured: it is a sibling
  // field of the template, and CodeMirror's extensions are built only once.
  const perItem =
    typeof domainOpts.perItem === "function"
      ? domainOpts.perItem
      : () => !!domainOpts.perItem;

  // Both shapes are assembled up front so switching mode costs nothing; the
  // expensive part, resolving the input schema, already happened.
  const scopes = {
    allItems: buildLiquidScope({ ...domainOpts, perItem: false }),
    perItem: buildLiquidScope({ ...domainOpts, perItem: true }),
  };
  const scope = () => (perItem() ? scopes.perItem : scopes.allItems);

  return [
    cmParams.utils.liquidLanguage(),
    buildTheme(cmParams),
    buildAutoCloseDelimiters(cmParams),
    buildLiquidDragDrop(cmParams, { perItem }),
    buildLiquidCompletions(cmParams, { scope, sections }),
  ];
}
