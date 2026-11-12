// Clicks below the last line hit the scroller, which CodeMirror's pointer
// handling ignores (it's wired to the content element). Listen here instead.
export function buildFocusEmptyArea({ cmView }) {
  const { ViewPlugin } = cmView;

  return ViewPlugin.fromClass(
    class {
      constructor(view) {
        this.view = view;
        this.onMouseDown = (event) => {
          // Scrollbar clicks also target the scroller, but outside its client box.
          if (
            event.target !== view.scrollDOM ||
            event.offsetX > view.scrollDOM.clientWidth ||
            event.offsetY > view.scrollDOM.clientHeight
          ) {
            return;
          }
          event.preventDefault();
          view.focus();
          view.dispatch({ selection: { anchor: view.state.doc.length } });
        };
        view.scrollDOM.addEventListener("mousedown", this.onMouseDown);
      }

      destroy() {
        this.view.scrollDOM.removeEventListener("mousedown", this.onMouseDown);
      }
    }
  );
}
