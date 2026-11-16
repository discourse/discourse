import { expectTypeOf } from "expect-type";
import { BadgeSchema } from "discourse/data/schemas/badge";
import WarpRestModel, {
  attachMeta,
  defineFieldForwarders,
  requestMany,
  requestOne,
  type WarpRequest,
  type WarpResource,
  type WarpRestBuilders,
} from "discourse/data/warp-rest-model";

/** Rejects an untyped return without choosing a promise implementation. */
type IsPromise<T> = 0 extends 1 & T
  ? false
  : [T] extends [never]
    ? false
    : [T] extends [Promise<unknown>]
      ? true
      : false;

type PromiseResult<T> = IsPromise<T> extends true ? Awaited<T> : never;

const request: WarpRequest = {
  url: "/gizmos.json",
  method: "GET",
  op: "query",
};

class Gizmo extends WarpRestModel {
  static override type = "gizmo";

  declare id: number;
  declare name: string;
}

/* Static surface kept as is */

expectTypeOf(WarpRestModel.type).toEqualTypeOf<string | null>();
expectTypeOf(WarpRestModel.builders).toEqualTypeOf<WarpRestBuilders | null>();
expectTypeOf(WarpRestModel.normalize).not.toBeAny();
expectTypeOf(WarpRestModel).not.toHaveProperty("create");

/* Factories return the subclass */

/** Calls, not `ReturnType`: that resolves a `this`-generic static against the base. */
const listing = Gizmo.findAll();
expectTypeOf(listing).resolves.toExtend<Gizmo[]>();
declare const listed: PromiseResult<typeof listing>;
expectTypeOf(Gizmo.findAll).returns.not.toBeAny();
expectTypeOf(listed).toExtend<Gizmo[]>();
expectTypeOf(listed[0]).toEqualTypeOf<Gizmo>();
/** Document `meta` keys are copied onto the list, with no declared shape. */
expectTypeOf(listed.grant_count).toEqualTypeOf<unknown>();
expectTypeOf(listed.length).toEqualTypeOf<number>();
Gizmo.findAll();
Gizmo.findAll({ onlyListable: true });

const finding = Gizmo.findById(1);
expectTypeOf(finding).resolves.toEqualTypeOf<Gizmo>();
Gizmo.findById(1);
Gizmo.findById("1");

const ingested = Gizmo.createFromJson({ gizmos: [] });
expectTypeOf(ingested).not.toBeAny();
expectTypeOf(ingested).toExtend<Gizmo | Gizmo[]>();
expectTypeOf<Gizmo>().toExtend<typeof ingested>();
Gizmo.createFromJson(null);
Gizmo.createFromJson(undefined);

/* A declared single-record root narrows ingest */

class Gadget extends WarpRestModel {
  declare static singleRecordRoot: "gadget";
}

class SpecialGadget extends Gadget {
  declare special: boolean;
}

class Sprocket extends WarpRestModel {
  declare static singleRecordRoot: "sprocket";
}

interface GadgetPayload {
  gadget: { id: number };
}

interface GadgetListPayload {
  gadgets: { id: number }[];
}

declare const gadgetPayload: GadgetPayload;
declare const gadgetListPayload: GadgetListPayload;

expectTypeOf(Gadget.createFromJson(gadgetPayload)).toEqualTypeOf<Gadget>();
expectTypeOf(Gadget.createFromJson(gadgetListPayload)).toEqualTypeOf<
  Gadget[]
>();
expectTypeOf(Gadget.createFromJson({ gadget: null })).toEqualTypeOf<Gadget[]>();
// A missing payload still wraps a single (empty) record.
expectTypeOf(Gadget.createFromJson(null)).toEqualTypeOf<Gadget>();
expectTypeOf(
  SpecialGadget.createFromJson(gadgetPayload)
).toEqualTypeOf<SpecialGadget>();
// Roots belong to their class.
expectTypeOf(Sprocket.createFromJson(gadgetPayload)).toEqualTypeOf<
  Sprocket[]
>();
expectTypeOf(Gizmo.createFromJson(gadgetPayload)).toEqualTypeOf<
  Gizmo | Gizmo[]
>();

/** The root may or may not be present, so either shape can come back. */
declare const maybeGadget: { gadget?: { id: number } | null };
declare const loosePayload: Record<string, unknown>;
expectTypeOf(Gadget.createFromJson(maybeGadget)).toEqualTypeOf<
  Gadget | Gadget[]
>();
expectTypeOf(Gadget.createFromJson(loosePayload)).toEqualTypeOf<
  Gadget | Gadget[]
>();

/** Open payloads that never carry the root say so. */
declare const openListPayload: {
  gadget?: never;
  gadgets: { id: number }[];
  [key: string]: unknown;
};
expectTypeOf(Gadget.createFromJson(openListPayload)).toEqualTypeOf<Gadget[]>();

/* Request helpers are generic over the class */

expectTypeOf(requestMany(Gizmo, request)).resolves.toExtend<Gizmo[]>();
expectTypeOf(requestMany(Gizmo, request)).resolves.not.toBeAny();
expectTypeOf(requestOne(Gizmo, request)).resolves.toEqualTypeOf<Gizmo>();

const withMeta = attachMeta([1, 2], { grant_count: 2 });
expectTypeOf(withMeta).toExtend<number[]>();
expectTypeOf(withMeta).not.toBeAny();

/* Schema forwarders take a resource schema */

defineFieldForwarders(Gizmo, BadgeSchema);
// @ts-expect-error a type name is not a schema
defineFieldForwarders(Gizmo, "badge");

/* Instance members */

declare const gizmo: Gizmo;
expectTypeOf(gizmo.__resource).toEqualTypeOf<WarpResource | null | undefined>();
expectTypeOf(gizmo.__ownResource).toEqualTypeOf<
  WarpResource | null | undefined
>();
expectTypeOf(gizmo.destroy()).resolves.toEqualTypeOf<void>();
expectTypeOf(gizmo.save({ name: "x" })).resolves.toEqualTypeOf<Gizmo>();
expectTypeOf(gizmo.updateFromJson({ gizmo: { id: 1 } })).toExtend<
  Gizmo | undefined
>();
expectTypeOf(gizmo.updateFromJson(null)).not.toBeAny();
gizmo._adoptResource(1);
gizmo._adoptResource("1");
gizmo._adoptResource(undefined);
gizmo._applyExtraAttributes(1);
gizmo._applyExtraAttributes(null);

/* A subclass may resolve its resource itself and return nothing from ingest */

class OwnResourceGizmo extends WarpRestModel {
  #draft: Record<string, unknown> = {};

  override get __resource(): Record<string, unknown> | undefined {
    return this.#draft;
  }

  override updateFromJson(json: Record<string, unknown> | null): undefined {
    this.#draft = { ...json };
  }
}

expectTypeOf(new OwnResourceGizmo().__resource).toEqualTypeOf<
  Record<string, unknown> | undefined
>();
