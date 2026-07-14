import { ajax } from "discourse/lib/ajax";

// Debounce for the server-side expression preview request. Matches the
// editor autosave debounce so typing produces at most one request per pause.
const EXPRESSION_EVALUATE_DEBOUNCE_MS = 750;

export function buildExpressionEvaluation(
  { cmState, cmView },
  { workflowId, nodeId, onSegmentsResolved }
) {
  const { StateEffect, StateField } = cmState;
  const { Decoration, EditorView, ViewPlugin } = cmView;

  const MARKS = {
    valid: Decoration.mark({ class: "cm-wf-valid-expression" }),
    invalid: Decoration.mark({ class: "cm-wf-invalid-expression" }),
    undefined: Decoration.mark({ class: "cm-wf-invalid-expression" }),
    empty: Decoration.mark({ class: "cm-wf-empty-expression" }),
    warning: Decoration.mark({ class: "cm-wf-warning-expression" }),
    pending: Decoration.mark({ class: "cm-wf-pending-expression" }),
  };

  const setSegmentsEffect = StateEffect.define();

  const field = StateField.define({
    create() {
      return Decoration.none;
    },
    update(decorations, tr) {
      decorations = decorations.map(tr.changes);

      for (const effect of tr.effects) {
        if (effect.is(setSegmentsEffect)) {
          const ranges = effect.value.filter(
            (seg) =>
              seg.kind === "resolved" &&
              seg.from !== undefined &&
              seg.to !== undefined
          );
          decorations = ranges.length
            ? Decoration.set(
                ranges.map(({ from, to, state }) =>
                  (MARKS[state] || MARKS.invalid).range(from, to)
                ),
                true
              )
            : Decoration.none;
        }
      }

      return decorations;
    },
    provide: (f) => EditorView.decorations.from(f),
  });

  const viewPlugin = ViewPlugin.fromClass(
    class {
      timeout = null;
      destroyed = false;
      lastEvaluatedTemplate = null;

      constructor(view) {
        this.view = view;
        if (workflowId && nodeId && view.state.doc.toString()) {
          this.evaluate();
        }
      }

      update(update) {
        if (update.docChanged) {
          this.scheduleEvaluation();
        } else if (
          update.focusChanged &&
          update.view.hasFocus &&
          update.view.state.doc.toString()
        ) {
          // Focusing a field doesn't change its content, so the dedupe guard
          // in evaluate() collapses this to a no-op unless it's never been
          // resolved (e.g. first focus on a freshly-loaded field).
          this.evaluate();
        }
      }

      scheduleEvaluation() {
        clearTimeout(this.timeout);
        const template = this.view.state.doc.toString();
        if (!template) {
          // Record the empty template so retyping the same value as before
          // (after clearing) is treated as a change and re-evaluated.
          this.lastEvaluatedTemplate = "";
          this.timeout = setTimeout(() => {
            if (this.destroyed) {
              return;
            }
            this.dispatch([]);
          }, 0);
          return;
        }
        this.timeout = setTimeout(
          () => this.evaluate(),
          EXPRESSION_EVALUATE_DEBOUNCE_MS
        );
      }

      async evaluate() {
        const template = this.view.state.doc.toString();

        // Reuse the previous result when the template is unchanged instead of
        // re-requesting (e.g. on refocus or a debounce that fired with no net
        // edit). Keeps a steadily-typed field within the endpoint's limit.
        if (template === this.lastEvaluatedTemplate) {
          return;
        }
        this.lastEvaluatedTemplate = template;

        try {
          const result = await ajax(
            "/admin/plugins/discourse-workflows/expressions/evaluate.json",
            {
              type: "POST",
              data: { template, workflow_id: workflowId, node_id: nodeId },
            }
          );

          if (this.destroyed || template !== this.view.state.doc.toString()) {
            return;
          }

          this.dispatch(result.segments || []);
        } catch {
          // Ignore failures for templates the editor has already moved past; a
          // newer in-flight request owns the current content.
          if (this.destroyed || template !== this.view.state.doc.toString()) {
            return;
          }
          // Allow a retry of the current template after a failure (e.g. a
          // transient 429/network error) rather than caching the failure.
          this.lastEvaluatedTemplate = null;
          this.dispatch([]);
        }
      }

      dispatch(segments) {
        this.view.dispatch({
          effects: setSegmentsEffect.of(segments),
        });
        onSegmentsResolved?.(segments);
      }

      destroy() {
        clearTimeout(this.timeout);
        this.destroyed = true;
      }
    }
  );

  return [field, viewPlugin];
}
