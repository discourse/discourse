// Removes Playwright's actionability "stable" wait from pointer actions.
//
// System specs run with `Capybara.disable_animation = true`, which injects
// CSS forcing `transition: none / animation: none` into every page — so
// elements never tween. Playwright cannot know that: before every pointer
// action (click, hover, check, drag…) its injected script still samples the
// element's bounding rect on two consecutive animationFrames and only
// proceeds once the rect is identical, which at headless Chromium's 60fps
// vsync costs ~31ms per action even on a perfectly static page (measured:
// 33.3ms/click stock vs 2.3ms with checks skipped).
//
// This hook rewrites a single expression in playwright-core's
// lib/server/dom.js as it is loaded, dropping only "stable" from the
// element-state list. Everything else in the actionability pipeline is
// preserved: visible/enabled checks, scroll-into-view, clickable-point
// computation, and the hit-target interception that detects a click landing
// on the wrong element and retries the whole loop.
//
// If a playwright-core upgrade changes the expression, the replacement
// simply never matches and stock behavior (slower, never broken) remains.
"use strict";

const path = require("path");
const Module = require("module");

const TARGET_SUFFIX = path.join("playwright-core", "lib", "server", "dom.js");
const BEFORE =
  'waitForEnabled ? ["visible", "enabled", "stable"] : ["visible", "stable"]';
const AFTER = 'waitForEnabled ? ["visible", "enabled"] : ["visible"]';

const originalCompile = Module.prototype._compile;
Module.prototype._compile = function (content, filename) {
  if (filename.endsWith(TARGET_SUFFIX) && content.includes(BEFORE)) {
    content = content.replace(BEFORE, AFTER);
  }
  return originalCompile.call(this, content, filename);
};
