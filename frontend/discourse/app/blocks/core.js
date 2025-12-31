/**
 * Core block components for internal auto-discovery.
 *
 * This module exports only @block-decorated component classes.
 * Used by lib/blocks/registration.js for module-load-time discovery.
 *
 * DO NOT import from "discourse/blocks" here as it would cause
 * circular dependencies with block-outlet.gjs.
 *
 * @module discourse/blocks/core
 */
export { default as BlockGroup } from "discourse/blocks/block-group";
