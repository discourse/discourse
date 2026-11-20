import { i18n } from "discourse-i18n";
import { buildScope } from "../expression-context.js";
import { expressionUtils } from "../expression-language/index.js";
import { buildArgumentInfo } from "./argument-info.js";
import { buildAutoCloseBraces } from "./auto-close-braces.js";
import { buildCompletions } from "./completions.js";
import { buildDragDrop } from "./drag-drop.js";
import { buildExpressionEvaluation } from "./expression-evaluation.js";
import { buildFocusEmptyArea } from "./focus-empty-area.js";
import { buildHoverTooltip } from "./hover-tooltip.js";
import { buildReferencePills } from "./reference-pills.js";
import { buildTheme } from "./theme.js";
import { buildValidation } from "./validation.js";

export default function buildExpressionExtensions(
  editorParams,
  domainOpts = {}
) {
  const utils = expressionUtils(editorParams);
  const cmParams = { ...editorParams, utils };
  const itemPrefix = domainOpts.itemPrefix || "$json";
  const SECTION_NODES = utils.section(
    i18n("discourse_workflows.expression_docs.sections.previous_nodes"),
    1
  );
  const sections = { ...utils.sections, nodes: SECTION_NODES };

  const scope = domainOpts.scope ?? buildScope(domainOpts);
  const ancestorNodes = domainOpts.ancestorNodes || [];
  const completionOpts = { scope, ancestorNodes, sections };
  const onOpenReferencePicker = domainOpts.onOpenReferencePicker;

  return [
    utils.expressionLanguage(),
    buildTheme(cmParams),
    buildValidation(cmParams),
    buildAutoCloseBraces(cmParams),
    buildDragDrop(cmParams, { itemPrefix, scope, onOpenReferencePicker }),
    buildReferencePills(cmParams, { scope, onOpenReferencePicker }),
    buildFocusEmptyArea(cmParams),
    buildCompletions(cmParams, completionOpts),
    buildHoverTooltip(cmParams, completionOpts),
    buildArgumentInfo(cmParams, completionOpts),
    buildExpressionEvaluation(cmParams, {
      workflowId: domainOpts.workflowId,
      nodeId: domainOpts.nodeId,
      onSegmentsResolved: domainOpts.onSegmentsResolved,
    }),
  ];
}
