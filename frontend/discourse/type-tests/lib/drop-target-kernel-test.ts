import { dropTargetForExternal } from "@atlaskit/pragmatic-drag-and-drop/adapter/drop-target-for-external";
import {
  dropTargetForElements,
  ElementDragPayload,
} from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import type { ExternalDragPayload } from "@atlaskit/pragmatic-drag-and-drop/adapter/external-adapter-types";
import type { CleanupFn } from "@atlaskit/pragmatic-drag-and-drop/types";
import { expectTypeOf } from "expect-type";
import type { DropTargetRegistrationArgs } from "discourse/lib/-internals/drag-and-drop/drop-target-kernel";

// Both library registrars accept the kernel's registration shape as-is, so an
// adapter hands them to the kernel without a cast.
expectTypeOf(dropTargetForElements).toMatchTypeOf<
  (args: DropTargetRegistrationArgs<ElementDragPayload>) => CleanupFn
>();
expectTypeOf(dropTargetForExternal).toMatchTypeOf<
  (args: DropTargetRegistrationArgs<ExternalDragPayload>) => CleanupFn
>();
