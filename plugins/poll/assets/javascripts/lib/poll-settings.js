import { isBlank } from "@ember/utils";

export const BAR_CHART_TYPE = "bar";
export const PIE_CHART_TYPE = "pie";

export const REGULAR_POLL_TYPE = "regular";
export const NUMBER_POLL_TYPE = "number";
export const MULTIPLE_POLL_TYPE = "multiple";
export const RANKED_CHOICE_POLL_TYPE = "ranked_choice";

export const ALWAYS_POLL_RESULT = "always";

export function pollAttrsFromSettings(
  settings,
  { originalAttrs, optionCount, maximumOptions }
) {
  const isNumber = settings.pollType === NUMBER_POLL_TYPE;
  const hasRange = isNumber || settings.pollType === MULTIPLE_POLL_TYPE;
  const originalClose = originalAttrs?.close;
  let close = null;

  if (settings.pollAutoClose) {
    close =
      originalClose && moment(originalClose).isSame(settings.pollAutoClose)
        ? originalClose
        : settings.pollAutoClose.toISOString();
  }

  const attrs = {
    name: originalAttrs?.name ?? null,
    type: settings.pollType || null,
    results: settings.pollResult || null,
    min: hasRange ? rangeAttr(settings.pollMin) : null,
    max: hasRange ? rangeAttr(settings.pollMax) : null,
    step: isNumber ? String(Math.max(Number(settings.pollStep) || 1, 1)) : null,
    public: String(settings.publicPoll),
    chartType: !isNumber && settings.chartType ? settings.chartType : null,
    dynamic: settings.dynamic ? "true" : null,
    groups: settings.pollGroups?.length ? settings.pollGroups.join(",") : null,
    close,
    status: originalAttrs?.status ?? null,
    order: originalAttrs?.order ?? null,
  };

  if (originalAttrs) {
    const impliedAttrs = {
      type: REGULAR_POLL_TYPE,
      results: ALWAYS_POLL_RESULT,
      public: "false",
      chartType: BAR_CHART_TYPE,
      min: "1",
      max: String(isNumber ? maximumOptions : optionCount),
      step: "1",
    };

    // Preserve omitted defaults so bounds can still follow later option changes.
    for (const [name, value] of Object.entries(impliedAttrs)) {
      if (attrs[name] === value && !originalAttrs[name]) {
        attrs[name] = null;
      }
    }
  }

  return attrs;
}

function rangeAttr(value) {
  if (isBlank(value) || !Number.isFinite(Number(value))) {
    return null;
  }

  return String(Number(value));
}
