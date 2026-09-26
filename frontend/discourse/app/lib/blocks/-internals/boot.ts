import * as BuiltinBlocks from "discourse/blocks/builtin";
import * as conditions from "discourse/blocks/conditions";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import {
  _freezeBlockRegistry,
  _registerBlock,
  _registerBlockFactory,
} from "discourse/lib/blocks/-internals/registry/block";
import {
  _freezeConditionTypeRegistry,
  _registerConditionType,
} from "discourse/lib/blocks/-internals/registry/condition";
import {
  _freezeOutletRegistry,
  _registerOutlet,
} from "discourse/lib/blocks/-internals/registry/outlet";
import { drainPendingRegistrations } from "discourse/lib/blocks/-internals/pending";

/**
 * Narrows a value exported from `discourse/blocks/conditions` to a concrete
 * `BlockCondition` subclass, mirroring the runtime check the "any" branch of
 * the loop below relies on: only classes whose prototype chain reaches
 * `BlockCondition` (excluding the base class itself) are condition types —
 * the module's other exports (`blockCondition`, built-in condition classes'
 * shared base) are plain functions or the base class and must be skipped.
 */
function isConditionClass(
  candidate: unknown
): candidate is typeof conditions.BlockCondition {
  return (
    typeof candidate === "function" &&
    (candidate as { prototype: unknown }).prototype instanceof
      conditions.BlockCondition &&
    candidate !== conditions.BlockCondition
  );
}

let booted = false;

// Registers the built-in blocks and condition types, applies registrations
// plugins queued before the block system loaded, and freezes the registries.
// Runs once, the first time a layout is rendered.
export default function bootBlocks(): void {
  if (booted) {
    return;
  }
  booted = true;

  for (const BlockClass of Object.values(BuiltinBlocks)) {
    if (typeof BlockClass === "function" && getBlockMetadata(BlockClass)) {
      _registerBlock(BlockClass);
    }
  }

  for (const exported of Object.values(conditions)) {
    if (isConditionClass(exported)) {
      _registerConditionType(exported);
    }
  }

  for (const { kind, args, source } of drainPendingRegistrations()) {
    if (kind === "block") {
      _registerBlock(args[0], source);
    } else if (kind === "block-factory") {
      _registerBlockFactory(args[0], args[1], source);
    } else if (kind === "outlet") {
      _registerOutlet(args[0], args[1], source);
    } else if (kind === "condition-type") {
      _registerConditionType(args[0], source);
    }
  }

  _freezeBlockRegistry();
  _freezeOutletRegistry();
  _freezeConditionTypeRegistry();
}

export function _resetBlocksBootForTesting(): void {
  booted = false;
}
