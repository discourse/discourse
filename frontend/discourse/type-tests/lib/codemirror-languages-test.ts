import type { Extension } from "@codemirror/state";
import { expectTypeOf } from "expect-type";
import {
  type CodemirrorExtensionBuilder,
  type CodemirrorLanguageBuilder,
  type CodemirrorParams,
  loadCodemirrorLanguage,
  registerCodemirrorLanguage,
} from "discourse/lib/codemirror-languages";

// The module namespaces plugins receive are the real ones, not loose objects.
expectTypeOf<CodemirrorParams["cmView"]["EditorView"]>().toEqualTypeOf<
  typeof import("@codemirror/view").EditorView
>();

// Both kinds of builder produce CodeMirror extensions; a language may return
// a single one, the editor argument has to return a list it can spread.
expectTypeOf<CodemirrorLanguageBuilder>().returns.toEqualTypeOf<Extension>();
expectTypeOf<CodemirrorExtensionBuilder>().returns.toEqualTypeOf<
  readonly Extension[]
>();

// A shortcut resolves to a builder, or to null so the editor can fall back to
// plain text.
expectTypeOf(
  loadCodemirrorLanguage("sql")
).resolves.toEqualTypeOf<CodemirrorLanguageBuilder | null>();

// A registered loader's module has to default-export a builder.
expectTypeOf(registerCodemirrorLanguage)
  .parameter(1)
  .returns.resolves.toHaveProperty("default")
  .toEqualTypeOf<CodemirrorLanguageBuilder>();
