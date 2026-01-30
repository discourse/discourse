declare module '@ember-compat/tracked-builtins/dist/-private/map' {
	 class TrackedMap<K = unknown, V = unknown> implements Map<K, V> {
	    private collection;
	    private storages;
	    private vals;
	    private readStorageFor;
	    private dirtyStorageFor;
	    constructor();
	    constructor(entries: readonly (readonly [K, V])[] | null);
	    constructor(iterable: Iterable<readonly [K, V]>);
	    // **** KEY GETTERS ****
	    get(key: K): V | undefined;
	    has(key: K): boolean;
	    // **** ALL GETTERS ****
	    entries(): IterableIterator<[K, V]>;
	    keys(): IterableIterator<K>;
	    values(): IterableIterator<V>;
	    forEach(fn: (value: V, key: K, map: Map<K, V>) => void): void;
	    get size(): number;
	    [Symbol.iterator](): IterableIterator<[K, V]>;
	    get [Symbol.toStringTag](): string;
	    // **** KEY SETTERS ****
	    set(key: K, value: V): this;
	    delete(key: K): boolean;
	    // **** ALL SETTERS ****
	    clear(): void;
	} class TrackedWeakMap<K extends object = object, V = unknown> implements WeakMap<K, V> {
	    private storages;
	    private vals;
	    private readStorageFor;
	    private dirtyStorageFor;
	    constructor();
	    constructor(iterable: Iterable<readonly [K, V]>);
	    constructor(entries: readonly [K, V][] | null);
	    get(key: K): V | undefined;
	    has(key: K): boolean;
	    set(key: K, value: V): this;
	    delete(key: K): boolean;
	    get [Symbol.toStringTag](): string;
	}
	export { TrackedMap, TrackedWeakMap };

}
declare module '@ember-compat/tracked-builtins/dist/-private/set' {
	 class TrackedSet<T = unknown> implements Set<T> {
	    private collection;
	    private storages;
	    private vals;
	    private storageFor;
	    private dirtyStorageFor;
	    constructor();
	    constructor(values: readonly T[] | null);
	    constructor(iterable: Iterable<T>);
	    // **** KEY GETTERS ****
	    has(value: T): boolean;
	    // **** ALL GETTERS ****
	    entries(): IterableIterator<[T, T]>;
	    keys(): IterableIterator<T>;
	    values(): IterableIterator<T>;
	    forEach(fn: (value1: T, value2: T, set: Set<T>) => void): void;
	    get size(): number;
	    [Symbol.iterator](): IterableIterator<T>;
	    get [Symbol.toStringTag](): string;
	    // **** KEY SETTERS ****
	    add(value: T): this;
	    delete(value: T): boolean;
	    // **** ALL SETTERS ****
	    clear(): void;
	} class TrackedWeakSet<T extends object = object> implements WeakSet<T> {
	    private storages;
	    private vals;
	    private storageFor;
	    private dirtyStorageFor;
	    constructor(values?: readonly T[] | null);
	    has(value: T): boolean;
	    add(value: T): this;
	    delete(value: T): boolean;
	    get [Symbol.toStringTag](): string;
	}
	export { TrackedSet, TrackedWeakSet };

}
declare module '@ember-compat/tracked-builtins/dist/-private/array' {
	 class TrackedArray<T = unknown> {
	    #private;
	    /**
	     * Creates an array from an iterable object.
	     * @param iterable An iterable object to convert to an array.
	     */
	    /**
	     * Creates an array from an iterable object.
	     * @param iterable An iterable object to convert to an array.
	     */
	    static from<T>(iterable: Iterable<T> | ArrayLike<T>): TrackedArray<T>;
	    /**
	     * Creates an array from an iterable object.
	     * @param iterable An iterable object to convert to an array.
	     * @param mapfn A mapping function to call on every element of the array.
	     * @param thisArg Value of 'this' used to invoke the mapfn.
	     */
	    /**
	     * Creates an array from an iterable object.
	     * @param iterable An iterable object to convert to an array.
	     * @param mapfn A mapping function to call on every element of the array.
	     * @param thisArg Value of 'this' used to invoke the mapfn.
	     */
	    static from<T, U>(iterable: Iterable<T> | ArrayLike<T>, mapfn: (v: T, k: number) => U, thisArg?: unknown): TrackedArray<U>;
	    static of<T>(...arr: T[]): TrackedArray<T>;
	    constructor(arr?: T[]);
	}
	interface TrackedArray<T = unknown> extends Array<T> {
	}
	export { TrackedArray as default };
	//# sourceMappingURL=-private/array.d.ts.map
}
declare module '@ember-compat/tracked-builtins/dist/-private/decorator' {
	import { TrackedMap, TrackedWeakMap } from '@ember-compat/tracked-builtins/dist/-private/map';
	import { TrackedSet, TrackedWeakSet } from '@ember-compat/tracked-builtins/dist/-private/set';
	import TrackedArray from '@ember-compat/tracked-builtins/dist/-private/array'; function tracked<T>(obj: T[] | typeof Array): TrackedArray<T>; function tracked<T>(obj: Set<T> | typeof Set): TrackedSet<T>; function tracked<T, U>(obj: Map<T, U> | typeof Map): TrackedMap<T, U>; function tracked<T extends object>(obj: WeakSet<T> | typeof WeakSet): TrackedWeakSet<T>; function tracked<T extends object, U>(obj: WeakMap<T, U> | typeof WeakMap): TrackedWeakMap<T, U>; function tracked<T extends object>(obj: T | typeof Object): T; function tracked(obj: object, key: string | symbol, desc?: PropertyDescriptor): void;
	export { tracked as default };

}
declare module '@ember-compat/tracked-builtins/dist/-private/object' {
	interface TrackedObjectClass {
	    /**
	     * Returns an object created by key-value entries for properties and methods
	     * @param entries An iterable object that contains key-value entries for properties and methods.
	     *
	     * Note: interface matches the built-in types, which use `any`, for maximum compat.
	     */
	    fromEntries<T = any>(entries: Iterable<readonly [PropertyKey, T]>): {
	        [k: string]: T;
	    };
	    /**
	     * Returns an object created by key-value entries for properties and methods
	     * @param entries An iterable object that contains key-value entries for properties and methods.
	     *
	     * Note: interface matches the built-in types, which use `any`, for maximum compat.
	     */
	    fromEntries<T>(entries: Iterable<readonly [any, T][]>): Record<string, T>;
	    new <T extends Record<PropertyKey, unknown> = Record<PropertyKey, unknown>>(obj?: T): T;
	} const TrackedObject: TrackedObjectClass;
	type TrackedObject<T = {}> = T;
	export { TrackedObject as default };

}
declare module '@ember-compat/tracked-builtins/dist/index' {
	export { default as tracked } from '@ember-compat/tracked-builtins/dist/-private/decorator';
	export { default as TrackedArray } from '@ember-compat/tracked-builtins/dist/-private/array';
	export { default as TrackedObject } from '@ember-compat/tracked-builtins/dist/-private/object';
	export { TrackedMap, TrackedWeakMap } from '@ember-compat/tracked-builtins/dist/-private/map';
	export { TrackedSet, TrackedWeakSet } from '@ember-compat/tracked-builtins/dist/-private/set';

}
declare module '@ember-compat/tracked-builtins/dist/-private/property-storage-map' {
	 class PropertyStorageMap {
	    #private;
	    constructor(object: object);
	    consume(key: string | symbol): void;
	    update(key: string | symbol): void;
	}
	export { PropertyStorageMap };

}
declare module '@ember-compat/tracked-builtins/dist/-private/utils' {
	 function isAccessorDescriptor(descriptor: PropertyDescriptor): boolean; function cloneObjectWithAccessors<T extends Record<PropertyKey, unknown> = Record<PropertyKey, unknown>>(obj: T): T;
	export { isAccessorDescriptor, cloneObjectWithAccessors };

}
declare module '@ember-compat/tracked-builtins/dist/-private/validator-versions' {
	 const dirtyProperty: (object: object, property: PropertyKey) => void, consumeProperty: (object: object, property: PropertyKey) => void;
	export { dirtyProperty, consumeProperty };

}
