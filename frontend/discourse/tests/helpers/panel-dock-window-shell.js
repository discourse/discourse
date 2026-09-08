/**
 * The markup the server renders for a panel window, written into a document in
 * this page.
 *
 * A hand copy of `app/views/panel_windows/show.html.erb`, which exists because
 * a rendering test has no server to ask. `spec/requests/panel_windows_controller_spec.rb`
 * is what keeps the two honest; nothing here can detect a drift on its own.
 *
 * Parsed rather than built element by element, deliberately. The shell it
 * replaced created its nodes with the *opening* page's `createElement`, so they
 * carried the opener's realm and every `instanceof` in the application happened
 * to hold. A served document's nodes are parsed in the window's own realm, and
 * anything that tests against opener-realm nodes is testing an easier problem
 * than the one production has.
 */
const SHELL_MARKUP = `
  <div class="d-panel-dock-window">
    <main class="d-panel-dock-window__mount"></main>
    <div class="d-panel-dock-window__reconnecting" hidden>
      <div class="empty-state__container --text-only --panel-dock-reconnecting">
        <div class="empty-state">
          <h1 class="empty-state__title">This panel lost the page it belongs to</h1>
          <div class="empty-state__body">
            <p role="status" aria-live="polite" aria-atomic="true"></p>
          </div>
        </div>
      </div>
    </div>
    <div id="d-menu-portals" class="d-panel-dock-window__portals"></div>
    <div id="d-tooltip-portals" class="d-panel-dock-window__portals"></div>
    <div class="d-panel-dock-window__sprites" hidden></div>
  </div>
`;

/**
 * Writes the served shell into a document, as the server would have.
 *
 * @param {Document} doc - The document to serve into.
 * @param {string} key - The context the window was served for.
 * @returns {{ mount: HTMLElement }} The mount a panel would render into.
 */
export function writeShellFixture(doc, key) {
  doc.documentElement.dataset.dPanelDock = key;
  doc.body.innerHTML = SHELL_MARKUP;

  return { mount: doc.querySelector(".d-panel-dock-window__mount") };
}

/**
 * A document that is same-origin and reachable but is not a panel window.
 *
 * Stands in for the page a popup lands on when the shell was never served —
 * a login redirect, a 404, or an error page.
 */
export function writeForeignPage(doc) {
  doc.body.innerHTML = `<main id="main-outlet">Not a panel window</main>`;
}

/**
 * An iframe standing in for a separate browser window, and its document.
 *
 * @param {object} context - The test context; the frame is registered on
 * `context.frames` so a shared `afterEach` can remove it.
 */
export function shellWindow(context, key) {
  const frame = document.createElement("iframe");
  frame.setAttribute("aria-hidden", "true");
  frame.style.width = "600px";
  frame.style.height = "400px";
  document.body.appendChild(frame);
  context.frames.push(frame);

  const doc = frame.contentDocument;
  const { mount } = writeShellFixture(doc, key);
  return { doc, mount, frame };
}
