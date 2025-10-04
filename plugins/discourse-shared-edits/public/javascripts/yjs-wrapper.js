/**
 * YJS Wrapper for Discourse
 * This file wraps the YJS module and exposes it as window.Y for use in Discourse plugins
 */
import * as Y from './yjs.js';

window.Y = Y;
