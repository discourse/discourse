import type { Extension } from "@codemirror/state";
import { expectTypeOf } from "expect-type";
import {
  type CodeEditorExtensionBuilder,
  type CodeEditorLanguageBuilder,
  type CodeEditorParams,
  loadCodeEditorLanguage,
  registerCodeEditorLanguage,
} from "discourse/lib/code-editor-languages";

// The module namespaces plugins receive are the real ones, not loose objects.
expectTypeOf<CodeEditorParams["cmView"]["EditorView"]>().toEqualTypeOf<
  typeof import("@codemirror/view").EditorView
>();

// Both builders return editor extensions, which may themselves be lists.
expectTypeOf<CodeEditorLanguageBuilder>().returns.toEqualTypeOf<Extension>();
expectTypeOf<CodeEditorExtensionBuilder>().returns.toEqualTypeOf<Extension>();

// A shortcut resolves to a builder, or to null so the editor can fall back to
// plain text.
expectTypeOf(
  loadCodeEditorLanguage("sql")
).resolves.toEqualTypeOf<CodeEditorLanguageBuilder | null>();

// A registered loader's module has to default-export a builder.
expectTypeOf(registerCodeEditorLanguage)
  .parameter(1)
  .returns.resolves.toHaveProperty("default")
  .toEqualTypeOf<CodeEditorLanguageBuilder>();
