import "discourse/loader"; // sets up globalThis.define / globalThis.require — must come first
import "./globals.js";
import { PrettyTextRubyInterface } from "./pretty-text-ruby-interface.js";
import { registerCoreModules } from "./register-modules.js";

registerCoreModules();
globalThis.__PrettyText = PrettyTextRubyInterface;
