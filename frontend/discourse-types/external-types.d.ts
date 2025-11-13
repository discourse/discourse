/// <reference path="./node_modules/ember-source/types/stable/index.d.ts" />

declare module "@glimmer/component" {
  export { default } from "./node_modules/@glimmer/component/dist/index.js";
}

declare module "@glint/template/-private/integration" {
  export {
    AnyFunction,
    AnyContext,
    AnyBlocks,
    InvokeDirect,
    DirectInvokable,
    Invoke,
    InvokableInstance,
    Invokable,
    Context,
    HasContext,
    ModifierReturn,
    ComponentReturn,
    TemplateContext,
    FlattenBlockParams,
    NamedArgs,
    NamedArgsMarker,
    NamedArgNames,
    UnwrapNamedArgs,
  } from "./node_modules/@glint/template/-private/index.d.ts";
}

declare module "@glint/ember-tsc/-private/dsl" {
  export {
    resolve,
    resolveOrReturn,
    templateExpression,
    Globals,
    AnyFunction,
    AnyContext,
    AnyBlocks,
    InvokeDirect,
    DirectInvokable,
    Invoke,
    InvokableInstance,
    Invokable,
    Context,
    HasContext,
    ModifierReturn,
    ComponentReturn,
    TemplateContext,
    FlattenBlockParams,
    NamedArgs,
    NamedArgsMarker,
    NamedArgNames,
    UnwrapNamedArgs,
  } from "@types/@glint/ember-tsc/types/-private/dsl/index.d.ts";
}

declare module "qunit" {
  export { module, test } from "@types/qunit";
}
