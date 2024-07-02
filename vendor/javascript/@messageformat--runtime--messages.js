var e=function(){
/**
     * @param msgData - A map of locale codes to their function objects
     * @param defaultLocale - If not defined, default and initial locale is the first key of `msgData`
     */
function Messages(e,t){var a=this;this._data={};this._fallback={};this._defaultLocale=null;this._locale=null;Object.keys(e).forEach((function(r){if("toString"!==r){a._data[r]=e[r];void 0===t&&(t=r)}}));this.locale=t||null;this._defaultLocale=this.locale}Object.defineProperty(Messages.prototype,"availableLocales",{get:function(){return Object.keys(this._data)},enumerable:false,configurable:true});Object.defineProperty(Messages.prototype,"locale",{get:function(){return this._locale},set:function(e){this._locale=this.resolveLocale(e)},enumerable:false,configurable:true});Object.defineProperty(Messages.prototype,"defaultLocale",{get:function(){return this._defaultLocale},set:function(e){this._defaultLocale=this.resolveLocale(e)},enumerable:false,configurable:true});
/**
     * Add new messages to the accessor; useful if loading data dynamically
     *
     * @remarks
     * The locale code `lc` should be an exact match for the locale being updated, or empty to default to the current locale.
     * Use {@link Messages.resolveLocale} for resolving partial locale strings.
     *
     * If `keypath` is empty, adds or sets the complete message object for the corresponding locale.
     * If any keys in `keypath` do not exist, a new object will be created at that key.
     *
     * @param data - Hierarchical map of keys to functions, or a single message function
     * @param locale - If empty or undefined, defaults to `this.locale`
     * @param keypath - The keypath being added
     */Messages.prototype.addMessages=function(e,t,a){var r=t||String(this.locale);"function"!==typeof e&&(e=Object.keys(e).reduce((function(t,a){"toString"!==a&&(t[a]=e[a]);return t}),{}));if(Array.isArray(a)&&a.length>0){var l=this._data[r];for(var s=0;s<a.length-1;++s){var n=a[s];l[n]||(l[n]={});l=l[n]}l[a[a.length-1]]=e}else this._data[r]=e;return this};Messages.prototype.resolveLocale=function(e){var t=String(e);if(this._data[t])return e;if(e){while(t=t.replace(/[-_]?[^-_]*$/,""))if(this._data[t])return t;var a=this.availableLocales;var r=new RegExp("^"+e+"[-_]");for(var l=0;l<a.length;++l)if(r.test(a[l]))return a[l]}return null};
/**
     * Get the list of fallback locales
     *
     * @param locale - If empty or undefined, defaults to `this.locale`
     */Messages.prototype.getFallback=function(e){var t=e||String(this.locale);return this._fallback[t]||(t!==this.defaultLocale&&this.defaultLocale?[this.defaultLocale]:[])};Messages.prototype.setFallback=function(e,t){this._fallback[e]=Array.isArray(t)?t:null;return this};
/**
     * Check if `key` is a message function for the locale
     *
     * @remarks
     * `key` may be a `string` for functions at the root level, or `string[]` for
     * accessing hierarchical objects. If an exact match is not found and
     * `fallback` is true, the fallback locales are checked for the first match.
     *
     * @param key - The key or keypath being sought
     * @param locale - If empty or undefined, defaults to `this.locale`
     * @param fallback - If true, also checks fallback locales
     */Messages.prototype.hasMessage=function(e,t,a){var r=t||String(this.locale);var l=a?this.getFallback(r):null;return _has(this._data,r,e,l,"function")};
/**
     * Check if `key` is a message object for the locale
     *
     * @remarks
     * `key` may be a `string` for functions at the root level, or `string[]` for
     * accessing hierarchical objects. If an exact match is not found and
     * `fallback` is true, the fallback locales are checked for the first match.
     *
     * @param key - The key or keypath being sought
     * @param locale - If empty or undefined, defaults to `this.locale`
     * @param fallback - If true, also checks fallback locales
     */Messages.prototype.hasObject=function(e,t,a){var r=t||String(this.locale);var l=a?this.getFallback(r):null;return _has(this._data,r,e,l,"object")};
/**
     * Get the message or object corresponding to `key`
     *
     * @remarks
     * `key` may be a `string` for functions at the root level, or `string[]` for accessing hierarchical objects.
     * If an exact match is not found, the fallback locales are checked for the first match.
     *
     * If `key` maps to a message function, the returned value will be the result of calling it with `props`.
     * If it maps to an object, the object is returned directly.
     * If nothing is found, `key` is returned.
     *
     * @param key - The key or keypath being sought
     * @param props - Optional properties passed to the function
     * @param lc - If empty or undefined, defaults to `this.locale`
     */Messages.prototype.get=function(e,t,a){var r=a||String(this.locale);var l=_get(this._data[r],e);if(l)return"function"==typeof l?l(t):l;var s=this.getFallback(r);for(var n=0;n<s.length;++n){l=_get(this._data[s[n]],e);if(l)return"function"==typeof l?l(t):l}return e};return Messages}();function _get(e,t){if(!e)return null;var a=e;if(Array.isArray(t)){for(var r=0;r<t.length;++r){if("object"!==typeof a)return null;a=a[t[r]];if(!a)return null}return a}return"object"===typeof a?a[t]:null}function _has(e,t,a,r,l){var s=_get(e[t],a);if(s)return typeof s===l;if(r)for(var n=0;n<r.length;++n){s=_get(e[r[n]],a);if(s)return typeof s===l}return false}export{e as default};

