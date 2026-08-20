import { expectTypeOf } from "expect-type";
import DAG, {
  type DAGOptions,
  type DAGPosition,
  type DAGResolvedEntry,
} from "discourse/lib/dag";

// The value type threads through resolve(), entries(), and add().
const stringDag = new DAG<string>();
expectTypeOf(stringDag.resolve()).toEqualTypeOf<DAGResolvedEntry<string>[]>();
expectTypeOf(stringDag.resolve()[0].value).toEqualTypeOf<string>();
expectTypeOf(stringDag.entries()).toEqualTypeOf<
  Array<[string, string, DAGPosition]>
>();
expectTypeOf(stringDag.add).parameter(1).toEqualTypeOf<string>();

// from() infers the value type from its entries.
const numberDag = DAG.from([["a", 1]] as Array<[string, number, DAGPosition?]>);
expectTypeOf(numberDag).toEqualTypeOf<DAG<number>>();
expectTypeOf(numberDag.resolve()[0].value).toEqualTypeOf<number>();

// Omitting the type argument defaults the value to `unknown`.
expectTypeOf(new DAG().resolve()[0].value).toEqualTypeOf<unknown>();

// Lifecycle callbacks receive the value type.
expectTypeOf<DAGOptions<string>["onAddItem"]>()
  .parameter(1)
  .toEqualTypeOf<string>();
expectTypeOf<DAGOptions<string>["onReplaceItem"]>()
  .parameter(1)
  .toEqualTypeOf<string>();
expectTypeOf<DAGOptions<string>["onReplaceItem"]>()
  .parameter(2)
  .toEqualTypeOf<string>();
