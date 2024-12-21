export function composeSteps(transactions, prevState) {
  const { tr } = prevState;

  transactions.forEach((transaction) => {
    transaction.steps.forEach((step) => {
      tr.step(step);
    });
  });

  return tr;
}

export function getChangedRanges(tr, replaceTypes, rangeTypes) {
  const ranges = [];
  const { steps, mapping } = tr;
  const inverseMapping = mapping.invert();

  steps.forEach((step, i) => {
    if (!isValidStep(step, replaceTypes)) {
      return;
    }

    const rawRanges = [];
    const stepMap = step.getMap();
    const mappingSlice = mapping.slice(i);

    if (stepMap.ranges.length === 0 && isValidStep(step, rangeTypes)) {
      const { from, to } = step;
      rawRanges.push({ from, to });
    } else {
      stepMap.forEach((from, to) => {
        rawRanges.push({ from, to });
      });
    }

    rawRanges.forEach((range) => {
      const from = mappingSlice.map(range.from, -1);
      const to = mappingSlice.map(range.to);

      ranges.push({
        from,
        to,
        prevFrom: inverseMapping.map(from, -1),
        prevTo: inverseMapping.map(to),
      });
    });
  });

  return ranges.sort((a, z) => a.from - z.from);
}

export function isValidStep(step, types) {
  return types.some((type) => step instanceof type);
}

export function findTextBlocksInRange(doc, range) {
  const nodesWithPos = [];

  // define a placeholder for leaf nodes to calculate link position
  doc.nodesBetween(range.from, range.to, (node, pos) => {
    if (!node.isTextblock || !node.type.allowsMarkType("link")) {
      return;
    }

    nodesWithPos.push({ node, pos });
  });

  return nodesWithPos.map((textBlock) => ({
    text: doc.textBetween(
      textBlock.pos,
      textBlock.pos + textBlock.node.nodeSize,
      undefined,
      " "
    ),
    positionStart: textBlock.pos,
  }));
}
