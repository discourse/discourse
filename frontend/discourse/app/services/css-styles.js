import { schedule } from "@ember/runloop";
import Service from "@ember/service";
import { TrackedMap } from "@ember-compat/tracked-built-ins";

/**
 * Service for managing dynamic CSS rules grouped by stylesheet.
 *
 * Each stylesheet group renders as a separate `<style>` tag in the DStyles
 * component, providing isolation so that invalid CSS in one group does not
 * affect rules from other groups.
 *
 * @example
 * // In a component:
 * @service cssStyles;
 *
 * constructor(owner, args) {
 *   super(owner, args);
 *   this.#cleanup = this.cssStyles.addRule(
 *     ".my-container { container: my-name / inline-size; }",
 *     { stylesheet: "blocks" }
 *   );
 * }
 *
 * willDestroy() {
 *   super.willDestroy();
 *   this.#cleanup?.();
 * }
 */
export default class CssStylesService extends Service {
  #sheets = new TrackedMap();
  #nextId = 0;

  /**
   * Returns an array of stylesheet groups, each with a name and its CSS rules.
   * Used by DStyles to render separate `<style>` tags per group.
   *
   * @returns {Array<{name: string, rules: Array<{id: number, css: string}>}>}
   */
  get stylesheets() {
    const result = [];
    for (const [name, rules] of this.#sheets) {
      if (rules.size > 0) {
        result.push({
          name,
          rules: Array.from(rules.entries(), ([id, css]) => ({ id, css })),
        });
      }
    }
    return result;
  }

  /**
   * Adds a CSS rule to a named stylesheet group.
   *
   * @param {string} css - The CSS rule string to add.
   * @param {Object} [options] - Options for the rule.
   * @param {string} [options.stylesheet="dynamic"] - The stylesheet group name.
   *   Rules in the same group share a `<style>` tag.
   * @returns {() => void} A cleanup function that removes the rule when called.
   */
  addRule(css, { stylesheet = "dynamic" } = {}) {
    const id = this.#nextId++;

    // Mutations are deferred to afterRender to avoid backtracking rerender
    // assertions. DStyles reads from the TrackedMap during rendering, so
    // writing to it in the same render pass (e.g., from a component
    // constructor) would trigger Ember's autotracking assertion.
    schedule("afterRender", () => {
      if (!this.#sheets.has(stylesheet)) {
        this.#sheets.set(stylesheet, new TrackedMap());
      }
      this.#sheets.get(stylesheet).set(id, css);
    });

    return () => {
      schedule("afterRender", () => {
        const rules = this.#sheets.get(stylesheet);
        if (rules) {
          rules.delete(id);
          if (rules.size === 0) {
            this.#sheets.delete(stylesheet);
          }
        }
      });
    };
  }
}
