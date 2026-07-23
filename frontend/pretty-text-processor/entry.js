import "discourse/loader"; // sets up window.define / window.require — must come first
import { PrettyTextRubyInterface } from "./pretty-text-ruby-interface.js";
import { registerCoreModules } from "./register-modules.js";

registerCoreModules();
globalThis.__PrettyText = PrettyTextRubyInterface;
