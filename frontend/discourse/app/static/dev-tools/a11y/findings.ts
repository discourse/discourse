/**
 * Finding tiers drive both presentation and triage. `broken` colors the row and
 * feeds the Problems filter. `fragile` works in some assistive technology but
 * not others, so it stays outside that filter. `noted` is true but not a defect
 * and never enters the filter or a sweep.
 *
 * Rules carry no English: detectors emit an id plus parameters and the panel
 * renders the translation. This keeps `findingTrace` locale-independent when a
 * trace is pasted into a bug report.
 */
export type Tier = "broken" | "fragile" | "noted";

export interface Finding {
  readonly id: string;
  readonly tier: Tier;
  readonly params: Readonly<Record<string, string | number>>;
}

const RULES = Object.freeze([
  ["focus.not-in-tree", "broken"],
  ["focus.no-name", "broken"],
  ["cursor.dangling", "broken"],
  ["cursor.target-hidden", "broken"],
  ["cursor.not-item", "broken"],
  ["cursor.claim-missing", "fragile"],
  ["cursor.visual-diverged", "broken"],
  ["cursor.visual-diverged-conventional", "noted"],
  ["set.impossible", "broken"],
  ["set.disagrees", "noted"],
  ["role.missing-state", "broken"],
  ["role.missing-attribute", "fragile"],
  ["role.missing-attribute-defaulted", "noted"],
  ["name.describedby-echoes-name", "fragile"],
  ["name.from-title-only", "noted"],
  ["name.title-duplicates-name", "noted"],
  ["name.labelledby-partly-unresolved", "noted"],
  ["live.born-with-content", "broken"],
  ["live.born-with-content-alert", "fragile"],
  ["live.replaced-mid-session", "broken"],
  ["live.not-in-tree", "broken"],
  ["live.politeness-contradicts-role", "broken"],
  ["live.redundant-politeness", "noted"],
  ["announce.no-region", "broken"],
  ["announce.undelivered", "broken"],
  ["announce.text-mismatch", "noted"],
  ["announce.runaway", "fragile"],
] as const satisfies ReadonlyArray<readonly [string, Tier]>);

const TIERS: ReadonlyMap<string, Tier> = new Map(RULES);
const RULE_IDS: readonly string[] = Object.freeze(RULES.map(([id]) => id));

/** Returns the reviewed registry in stable order. */
export function ruleIds(): readonly string[] {
  return RULE_IDS;
}

/** Looks up a rule's tier without classifying unregistered ids. */
export function tierOf(id: string): Tier | undefined {
  return TIERS.get(id);
}

/** Records a finding for later translation and rejects unregistered ids. */
export function finding(
  id: string,
  params: Record<string, string | number> = {}
): Finding {
  const tier = tierOf(id);

  if (!tier) {
    throw new Error(`Accessibility rule "${id}" is not registered`);
  }

  return Object.freeze({
    id,
    tier,
    params: Object.freeze({ ...params }),
  });
}

/** Selects findings that feed the Problems filter. */
export function isProblem(recorded: Finding): boolean {
  return recorded.tier === "broken";
}

/** Serializes a locale-independent line suitable for a pasted bug report. */
export function findingTrace(recorded: Finding): string {
  const params = Object.entries(recorded.params).map(
    ([key, value]) => `${key}=${value}`
  );

  return [recorded.id, ...params].join(" ");
}

/** Derives the panel translation key for a rule. */
export function findingKey(id: string): string {
  return `dev_tools.a11y.findings.${id.replaceAll("-", "_")}`;
}
