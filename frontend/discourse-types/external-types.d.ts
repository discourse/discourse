/// <reference path="./node_modules/ember-source/types/stable/index.d.ts" />

declare module "@glimmer/component" {
  export { default } from "@types/glimmer__component";
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
  } from "@types/glint__template/-private/integration";
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
  } from "@types/glint__ember-tsc/-private/dsl";
}

declare module "qunit" {
  export { module, test } from "@types/qunit";
}
