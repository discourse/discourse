import { i18n } from "discourse-i18n";

export const SPECIAL_CHECKS = ["nothing", "finishes"];

export const CHECK_MODES = ["happens", "not_happens", "count"];

export const CONDITION_OPERATORS = [
  "equals",
  "not_equals",
  "contains",
  "not_contains",
];

const effectFields = new Map();

export function registerEffectTypes(effectTypes) {
  effectFields.clear();
  (effectTypes ?? []).forEach((entry) => {
    effectFields.set(entry.type, entry.fields ?? []);
  });
}

export function effectTypeNames() {
  return [...effectFields.keys()];
}

export function isSpecialCheck(effect) {
  return SPECIAL_CHECKS.includes(effect);
}

export function fieldsForEffect(effect) {
  return effectFields.get(effect) ?? [];
}

export function newCheck(effect = effectTypeNames()[0] ?? "finishes") {
  return {
    id: crypto.randomUUID(),
    effect,
    mode: "happens",
    count: 1,
    conditions: [],
  };
}

export function newCondition(effect) {
  return {
    id: crypto.randomUUID(),
    field: fieldsForEffect(effect)[0] ?? "",
    operator: "equals",
    value: "",
  };
}

export function checkFromEffect(effect) {
  const field = fieldsForEffect(effect.type)[0];
  const check = newCheck(effect.type);
  const value = effect.fields?.[field];
  if (field && value !== undefined && value !== null && value !== "") {
    check.conditions = [
      { ...newCondition(effect.type), field, value: String(value) },
    ];
  }
  return check;
}

function effectLabel(effect, count = 1) {
  return i18n(`discourse_workflows.tests.effects.${effect}`, { count });
}

function fieldLabel(effect, field) {
  const label = i18n(`discourse_workflows.tests.fields.${effect}.${field}`);
  return label.startsWith("[") ? field.replace(/_/g, " ") : label;
}

function capitalize(text) {
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function operatorLabel(operator) {
  return i18n(`discourse_workflows.if.operators.${operator}`);
}

function conditionsSentence(check) {
  const parts = (check.conditions ?? []).map((condition) =>
    i18n("discourse_workflows.tests.sentences.condition", {
      field: fieldLabel(check.effect, condition.field),
      operator: operatorLabel(condition.operator || "equals"),
      value: condition.value ?? "",
    })
  );

  return parts.length
    ? i18n("discourse_workflows.tests.sentences.where", {
        conditions: parts.join(i18n("discourse_workflows.tests.sentences.and")),
      })
    : "";
}

export function checkSentence(check) {
  if (!check) {
    return "";
  }
  if (check.effect === "nothing") {
    return i18n("discourse_workflows.tests.sentences.nothing");
  }
  if (check.effect === "finishes") {
    return i18n("discourse_workflows.tests.sentences.finishes");
  }

  const count = check.mode === "count" ? Number(check.count ?? 1) : 1;
  const effect = effectLabel(check.effect, count);
  const sentence = i18n(`discourse_workflows.tests.sentences.${check.mode}`, {
    effect,
    count,
  });

  return capitalize(`${sentence}${conditionsSentence(check)}`);
}

function formatValue(value) {
  if (typeof value === "string") {
    return value.length > 40 ? `"${value.slice(0, 40)}…"` : `"${value}"`;
  }
  if (Array.isArray(value)) {
    return value.join(", ");
  }
  return String(value);
}

export function effectSentence(effect) {
  const details = Object.entries(effect.fields ?? {})
    .filter(
      ([, value]) => value !== undefined && value !== null && value !== ""
    )
    .map(([field, value]) =>
      i18n("discourse_workflows.tests.sentences.effect_field", {
        field: fieldLabel(effect.type, field),
        value: formatValue(value),
      })
    );

  return capitalize(
    i18n("discourse_workflows.tests.sentences.effect", {
      effect: effectLabel(effect.type),
      details: details.join(", "),
    })
  );
}
