// Entry for the PrettyText mini-racer bundle. Sets up loader.js (so `define`/
// `require` become globals), registers the core module surface into it (so
// plugins keep `require(...)`-ing it), and exposes the PrettyTextRubyInterface
// class as `globalThis.__PrettyText`, whose static methods Ruby drives via
// `v8.call` (no eval).

import "discourse/loader"; // sets up window.define / window.require — must come first
import { PrettyTextRubyInterface } from "./pretty-text-ruby-interface.js";
import { registerCoreModules } from "./register-modules.js";

registerCoreModules();
globalThis.__PrettyText = PrettyTextRubyInterface;
