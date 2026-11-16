import { i18n } from "discourse-i18n";

const EFFORTS = Object.freeze([
  "default",
  "none",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
]);

export default function thinkingEffortOptions() {
  return EFFORTS.map((id) => ({
    id,
    name: i18n(`discourse_ai.ai_agent.thinking_effort_options.${id}`),
  }));
}
