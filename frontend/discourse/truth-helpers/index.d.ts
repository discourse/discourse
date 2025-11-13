// Type declarations for truth-helpers module
declare module "truth-helpers" {
  export function and(...args: unknown[]): boolean;
  export function eq<T>(left: T, right: T): boolean;
  export function gt(left: number, right: number): boolean;
  export function gte(left: number, right: number): boolean;
  export function has<T extends object>(obj: T, key: string): boolean;
  export function includes<T>(array: T[] | string, item: T | string): boolean;
  export function lt(left: number, right: number): boolean;
  export function lte(left: number, right: number): boolean;
  export function not(value: unknown): boolean;
  export function notEq<T>(left: T, right: T): boolean;
  export function or(...args: unknown[]): boolean;
}
