import { i18n } from "discourse-i18n";
import { buildScope } from "../expression-context";
import { buildArgumentInfo } from "./argument-info";
import { buildAutoCloseBraces } from "./auto-close-braces";
import { buildCompletions } from "./completions";
import { buildDragDrop } from "./drag-drop";
import { buildExpressionEvaluation } from "./expression-evaluation";
import { buildHoverTooltip } from "./hover-tooltip";
import { buildTheme } from "./theme";
import { buildValidation } from "./validation";

export default function buildExpressionExtensions(cmParams, domainOpts = {}) {
  const itemPrefix = domainOpts.itemPrefix || "$json";
  const SECTION_NODES = cmParams.utils.section(
    i18n("discourse_workflows.expression_docs.sections.previous_nodes"),
    1
  );
  const sections = { ...cmParams.utils.sections, nodes: SECTION_NODES };

  const scope = buildScope(domainOpts);
  const ancestorNodes = domainOpts.ancestorNodes || [];
  const completionOpts = { scope, ancestorNodes, sections };

  return [
    cmParams.utils.expressionLanguage(),
    buildTheme(cmParams),
    buildValidation(cmParams),
    buildAutoCloseBraces(cmParams),
    buildDragDrop(cmParams, { itemPrefix }),
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
