import type { CustomizationSource } from "discourse/lib/customization-source";

export type PendingRegistration = {
  kind: "block" | "block-factory" | "outlet" | "condition-type";
  args: unknown[];
  source?: CustomizationSource;
};

const pending: PendingRegistration[] = [];

// Registrations made before the block system loads wait here for it.
export function enqueueRegistration(registration: PendingRegistration): void {
  pending.push(registration);
}

export function drainPendingRegistrations(): PendingRegistration[] {
  return pending.splice(0);
}
