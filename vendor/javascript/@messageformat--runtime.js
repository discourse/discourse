function _nf(r){return _nf[r]||(_nf[r]=new Intl.NumberFormat(r))}
/**
 * Utility function for `#` in plural rules
 *
 * @param lc The current locale
 * @param value The value to operate on
 * @param offset An offset, set by the surrounding context
 * @returns The result of applying the offset to the input value
 */function number(r,n,t){return _nf(r).format(n-t)}
/**
 * Strict utility function for `#` in plural rules
 *
 * Will throw an Error if `value` or `offset` are non-numeric.
 *
 * @param lc The current locale
 * @param value The value to operate on
 * @param offset An offset, set by the surrounding context
 * @param name The name of the argument, used for error reporting
 * @returns The result of applying the offset to the input value
 */function strictNumber(r,n,t,e){var o=n-t;if(isNaN(o))throw new Error("`"+e+"` or its offset is not a number");return _nf(r).format(o)}
/**
 * Utility function for `{N, plural|selectordinal, ...}`
 *
 * @param value The key to use to find a pluralization rule
 * @param offset An offset to apply to `value`
 * @param lcfunc A locale function from `pluralFuncs`
 * @param data The object from which results are looked up
 * @param isOrdinal If true, use ordinal rather than cardinal rules
 * @returns The result of the pluralization
 */function plural(r,n,t,e,o){if({}.hasOwnProperty.call(e,r))return e[r];n&&(r-=n);var u=t(r,o);return u in e?e[u]:e.other}
/**
 * Utility function for `{N, select, ...}`
 *
 * @param value The key to use to find a selection
 * @param data The object from which results are looked up
 * @returns The result of the select statement
 */function select(r,n){return{}.hasOwnProperty.call(n,r)?n[r]:n.other}
/**
 * Checks that all required arguments are set to defined values
 *
 * Throws on failure; otherwise returns undefined
 *
 * @param keys The required keys
 * @param data The data object being checked
 */function reqArgs(r,n){for(var t=0;t<r.length;++t)if(!n||void 0===n[r[t]])throw new Error("Message requires argument '".concat(r[t],"'"))}export{_nf,number,plural,reqArgs,select,strictNumber};

