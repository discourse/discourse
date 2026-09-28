export const MAX_TABS = 5;
export const MORE_TAB = "more";

/**
 * Fits tabs into the bar. Past the limit, a "More" tab takes the last slot, as
 * it does in native tab bars, and holds the tabs that don't fit.
 *
 * @param {Array<Object>} tabs In display order.
 * @param {Object} options
 * @param {Array<string>} options.foldOrder Keys to move into "More" first;
 * the rest fold from the end of the bar. The first tab never folds.
 * @param {Array<string>} [options.keep] Keys that never fold.
 * @param {Object} options.moreTab The "More" tab, without its `overflow`.
 * @param {number} [options.max]
 * @returns {Array<Object>} The tabs to show. The "More" tab lists the tabs it
 * holds as `overflow`, in display order.
 */
export function arrangeTabs(
  tabs,
  { foldOrder, keep = [], moreTab, max = MAX_TABS }
) {
  if (tabs.length <= max) {
    return tabs;
  }

  const foldable = tabs.slice(1).filter((tab) => !keep.includes(tab.key));
  const candidates = [
    ...foldOrder
      .map((key) => foldable.find((tab) => tab.key === key))
      .filter(Boolean),
    ...foldable.filter((tab) => !foldOrder.includes(tab.key)).reverse(),
  ];

  // "More" takes a slot of its own
  const folded = new Set(candidates.slice(0, tabs.length - max + 1));
  const visible = tabs.filter((tab) => !folded.has(tab));

  return [
    ...visible,
    { ...moreTab, overflow: tabs.filter((tab) => folded.has(tab)) },
  ];
}
