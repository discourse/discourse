import type { ArgSchema } from "discourse/blocks/types";

/** An empty block argument that should display a configuration prompt. */
export interface EmptyPromptArgEntry {
  /** The argument schema. */
  def: ArgSchema;

  /** The argument name. */
  name: string;

  /** The prompt shown over the empty block. */
  prompt: string;
}

/**
 * Per-arg primitives for args that declare an editor `ui.emptyPrompt`. The
 * chrome uses these to decide which "configure me" prompts to paint over an
 * unconfigured block. Stays a pure module — no service reads, no DOM — so it
 * can be unit-tested with plain JS fixtures.
 *
 * A block declares the prompt on the arg that identifies it (e.g. a topic
 * card's `topicId`); when that arg is unset the block renders nothing useful,
 * so the editor invites the user to fill it in.
 */

/**
 * Returns the args on the schema that declare a `ui.emptyPrompt` AND are
 * currently unset, in declaration order. Each entry carries what the chrome
 * needs to paint the prompt:
 *
 *   - `name`: the arg name as it appears under `entry.args`
 *   - `def`: the raw schema entry (ui hints, …)
 *   - `prompt`: the resolved `ui.emptyPrompt` string to display
 *
 * An arg counts as unset when its live value is nullish (`value == null`).
 *
 * @param argsSchema - The block's args schema (the
 *   `args` field on block metadata, keyed by arg name).
 * @param liveArgs - The entry's live args object, keyed
 *   by arg name.
 * @returns Empty prompt descriptors in schema declaration order.
 */
export function emptyPromptArgEntries(
  argsSchema: Record<string, ArgSchema> | null | undefined,
  liveArgs: Record<string, unknown> | null | undefined
): EmptyPromptArgEntry[] {
  if (!argsSchema || typeof argsSchema !== "object") {
    return [];
  }
  const args = liveArgs ?? {};
  const out: EmptyPromptArgEntry[] = [];
  for (const [name, def] of Object.entries(argsSchema)) {
    const prompt = def?.ui?.emptyPrompt;
    if (typeof prompt !== "string" || prompt.length === 0) {
      continue;
    }
    if (args[name] == null) {
      out.push({ name, def, prompt });
    }
  }
  return out;
}
