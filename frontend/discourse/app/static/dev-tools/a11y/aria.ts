/**
 * Role metadata, derived from `aria-query` rather than hand-maintained.
 *
 * This is the only module that imports `aria-query`. Its published types lag
 * the runtime — `requiredOwnedElements`, `requiredContextRole` and
 * `accessibleNameRequired` all exist at 5.3.2 but are absent from
 * `@types/aria-query@5.0.4` — so the cast to the fields we actually use happens
 * here, once, and nowhere else.
 */

import { roles } from "aria-query";

interface RoleMetadata {
  abstract: boolean;
  requiredOwnedElements: ReadonlyArray<ReadonlyArray<string>>;
  requiredProps: Readonly<Record<string, string | null>>;
  superClass: ReadonlyArray<ReadonlyArray<string>>;
  accessibleNameRequired: boolean;
}

const metadataCache = new Map<string, RoleMetadata | undefined>();

function metadataFor(role: string): RoleMetadata | undefined {
  if (!metadataCache.has(role)) {
    metadataCache.set(
      role,
      (
        roles as unknown as {
          get(role: string): RoleMetadata | undefined;
        }
      ).get(role)
    );
  }

  return metadataCache.get(role);
}

function isCompositeMetadata(metadata: RoleMetadata): boolean {
  return (
    !metadata.abstract &&
    metadata.requiredOwnedElements.some((owned) => owned.length > 0) &&
    metadata.superClass.some((chain) => chain.includes("composite"))
  );
}

function isWidget(metadata: RoleMetadata): boolean {
  return metadata.superClass.some((chain) => chain.includes("widget"));
}

/** Whether the role is a composite widget that can own a virtual cursor. */
export function isComposite(role: string): boolean {
  const metadata = metadataFor(role);

  return metadata ? isCompositeMetadata(metadata) : false;
}

/** The roles a composite's cursor may legitimately target. */
export function itemRolesFor(role: string): ReadonlySet<string> {
  const metadata = metadataFor(role);
  if (!metadata || !isCompositeMetadata(metadata)) {
    return new Set();
  }

  const directRoles = metadata.requiredOwnedElements.flat();
  const candidates = new Set(directRoles);

  for (const directRole of directRoles) {
    const directMetadata = metadataFor(directRole);
    for (const owned of directMetadata?.requiredOwnedElements.flat() ?? []) {
      candidates.add(owned);
    }
  }

  return new Set(
    [...candidates].filter((candidate) => {
      const candidateMetadata = metadataFor(candidate);

      return candidateMetadata ? isWidget(candidateMetadata) : false;
    })
  );
}

/** Attributes the role requires, mapped to the default the spec supplies. */
export function requiredPropsFor(
  role: string
): ReadonlyMap<string, string | null> {
  const metadata = metadataFor(role);

  return new Map(Object.entries(metadata?.requiredProps ?? {}));
}

/** Whether the role is meaningless without an accessible name. */
export function requiresAccessibleName(role: string): boolean {
  return metadataFor(role)?.accessibleNameRequired ?? false;
}
