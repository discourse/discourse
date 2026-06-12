// Imperative renderer for the bundle analyzer UI. Ported from the standalone
// HTML report; builds the whole view into `root` from the JSON emitted by the
// bundle-analyzer rolldown plugin. Kept as plain DOM (rather than Glimmer) so
// it stays a faithful, self-contained copy of the original report.

const SKELETON = `
  <div class="ba-header">
    <span class="ba-sub" data-el="meta"></span>
  </div>
  <section>
    <h2>Initial page load</h2>
    <div class="ba-hint">
      Files and bytes downloaded before any dynamic import. Toggle which
      entrypoints count as the baseline.
    </div>
    <div class="ba-baseline" data-el="baseline"></div>
    <div class="ba-cards" data-el="initialCards"></div>
    <div class="ba-toolbar">
      <div class="ba-seg" data-el="sizeToggle">
        <button data-size="brotli" class="on">brotli</button>
        <button data-size="raw">raw</button>
      </div>
      <input type="search" data-el="search" placeholder="Filter files / modules…" />
    </div>
    <div data-el="initialList"></div>
  </section>
  <section>
    <h2>Dynamic entrypoints</h2>
    <div class="ba-hint">
      Each is loaded on demand via <code>import()</code>. “Additional” counts
      only chunks not already in the initial load above.
    </div>
    <div data-el="dynamicList"></div>
  </section>
`;

export function renderBundleAnalysis(root, D) {
  root.classList.add("bundle-analyzer");
  root.innerHTML = SKELETON;
  const q = (sel) => root.querySelector(`[data-el="${sel}"]`);

  const chunks = D.chunks;
  let sizeKey = "brotli";
  let filter = "";

  // For each chunk, which entrypoints (static or dynamic) pull it in —
  // i.e. whose static-import closure contains it.
  const entryRoots = [...D.entrypoints, ...D.dynamicEntrypoints];
  const usedByEntries = {};
  for (const f of Object.keys(chunks)) {
    usedByEntries[f] = [];
  }
  for (const e of entryRoots) {
    for (const f of staticClosure(e)) {
      if (usedByEntries[f] && !usedByEntries[f].includes(e)) {
        usedByEntries[f].push(e);
      }
    }
  }

  function stem(file) {
    return file.replace(/^assets\/js\//, "").replace(/\.digested\.js$/, "");
  }

  function routeName(c) {
    const m = (c.facadeModuleId || "").match(
      /-embroider-route-entrypoint\.js:route=(.+)$/
    );
    return m ? m[1] : null;
  }

  function sz(file) {
    const c = chunks[file];
    return c ? (sizeKey === "brotli" ? c.brotliSize : c.rawSize) : 0;
  }
  function fmt(n) {
    if (n >= 1048576) {
      return (n / 1048576).toFixed(2) + " MB";
    }
    if (n >= 1024) {
      return (n / 1024).toFixed(1) + " KB";
    }
    return n + " B";
  }
  function staticClosure(file, set) {
    set = set || new Set();
    if (set.has(file) || !chunks[file]) {
      return set;
    }
    set.add(file);
    for (const dep of chunks[file].imports) {
      staticClosure(dep, set);
    }
    return set;
  }
  function closureOf(files) {
    const set = new Set();
    for (const f of files) {
      staticClosure(f, set);
    }
    return set;
  }
  function totals(files) {
    let raw = 0,
      brotli = 0;
    for (const f of files) {
      raw += chunks[f].rawSize;
      brotli += chunks[f].brotliSize;
    }
    return { files: files.size || files.length, raw, brotli };
  }

  const baselineSel = new Set(
    D.entrypoints.filter((f) =>
      ["discourse", "vendor"].includes(chunks[f].name)
    )
  );
  if (baselineSel.size === 0) {
    D.entrypoints.forEach((f) => baselineSel.add(f));
  }

  function baselineClosure() {
    return closureOf([...baselineSel]);
  }

  // ---- rendering ----------------------------------------------------
  const el = (h) => {
    const t = document.createElement("template");
    t.innerHTML = h.trim();
    return t.content.firstElementChild;
  };
  function matches(text) {
    return !filter || text.toLowerCase().includes(filter);
  }

  function moduleRows(c) {
    const max = c.modules.length ? c.modules[0].renderedLength : 1;
    return c.modules
      .filter((m) => matches(m.id))
      .map(
        (m) => `
        <div class="ba-mod" title="${m.id}">
          <div>
            <div class="ba-mname">${m.id}</div>
            <div class="ba-bar"><span style="width:${Math.max(2, (m.renderedLength / max) * 100)}%"></span></div>
          </div>
          <div class="ba-num">${fmt(m.renderedLength)}</div>
        </div>`
      )
      .join("");
  }

  function chunkRow(file, opts = {}) {
    const c = chunks[file];
    const badges = [];
    if (!opts.root) {
      if (c.isEntry) {
        badges.push('<span class="ba-badge entry">entry</span>');
      }
      const route = routeName(c);
      if (route) {
        badges.push(`<span class="ba-badge route">route: ${route}</span>`);
      } else if (c.isDynamicEntry) {
        badges.push('<span class="ba-badge dyn">dynamic</span>');
      }
      if (opts.added) {
        badges.push('<span class="ba-badge add">added</span>');
      }
    }
    const label = opts.root
      ? '<span class="ba-label root">dynamic entrypoint root</span>'
      : `<span class="ba-label" title="${file}">${stem(file)} <span class="ba-pill">· ${c.moduleCount} modules</span></span>`;
    const row = el(`
      <div class="ba-row">
        <div class="ba-head">
          <div class="ba-name">
            <span class="ba-tw">▶</span>
            ${badges.join("")}
            ${label}
          </div>
          <div class="ba-num">${fmt(c.brotliSize)} <span class="ba-pill">br</span></div>
          <div class="ba-num muted">${fmt(c.rawSize)} <span class="ba-pill">raw</span></div>
          <div class="ba-num pill">${opts.root ? "" : usedByEntries[file].length + " ep"}</div>
        </div>
        <div class="ba-body"></div>
      </div>`);
    const body = row.querySelector(".ba-body");
    const head = row.querySelector(".ba-head");
    head.addEventListener("click", () => {
      row.classList.toggle("open");
      if (!body.dataset.filled) {
        const entries = usedByEntries[file];
        body.innerHTML =
          `<div class="ba-pill" style="margin:2px 0 6px">Used by entrypoints: ${
            entries.length ? entries.map(stem).join(", ") : "—"
          }</div>` + moduleRows(c);
        body.dataset.filled = "1";
      }
    });
    return row;
  }

  function dynamicCard(file) {
    const c = chunks[file];
    const loadSet = staticClosure(file);
    const base = baselineClosure();
    const added = [...loadSet].filter((f) => !base.has(f));
    const addTot = totals(added);
    const fullTot = totals(loadSet);

    const sites =
      c.importSites && c.importSites.length
        ? c.importSites
            .map(
              (s) =>
                `<div class="ba-site">imported by <code>${s.importer}${
                  s.line ? ":" + s.line : ""
                }</code>${s.specifier ? ` — <span class="ba-pill">import("${s.specifier}")</span>` : ""}</div>`
            )
            .join("")
        : '<div class="ba-site pill">no static import site found</div>';

    const card = el(`
      <div class="ba-row">
        <div class="ba-head" style="grid-template-columns:1fr 130px 130px 70px">
          <div class="ba-name">
            <span class="ba-tw">▶</span>
            ${
              routeName(c)
                ? `<span class="ba-badge route">route: ${routeName(c)}</span>`
                : '<span class="ba-badge dyn">dynamic</span>'
            }
            <span class="ba-label" title="${c.facadeModuleId || file}">${stem(file)}</span>
          </div>
          <div class="ba-num"><b>+${fmt(sizeKey === "brotli" ? addTot.brotli : addTot.raw)}</b> <span class="ba-pill">added</span></div>
          <div class="ba-num muted">${fmt(sizeKey === "brotli" ? fullTot.brotli : fullTot.raw)} <span class="ba-pill">total</span></div>
          <div class="ba-num pill">+${added.length}/${loadSet.size}f</div>
        </div>
        <div class="ba-body">
          <div class="ba-sites">${sites}</div>
          <div class="ba-pill" style="margin-bottom:6px">
            Adds <b>${added.length}</b> new files (${fmt(addTot.brotli)} br / ${fmt(addTot.raw)} raw);
            full subtree is ${loadSet.size} files.
          </div>
          <div class="ba-sub-list"></div>
        </div>
      </div>`);
    const sub = card.querySelector(".ba-sub-list");
    const head = card.querySelector(".ba-head");
    head.addEventListener("click", () => {
      card.classList.toggle("open");
      if (!sub.dataset.filled) {
        const addedSorted = added
          .filter((f) => f !== file)
          .sort((a, b) => sz(b) - sz(a));
        const sharedSorted = [...loadSet]
          .filter((f) => base.has(f) && f !== file)
          .sort((a, b) => sz(b) - sz(a));
        sub.innerHTML = "";
        sub.appendChild(chunkRow(file, { root: true }));
        for (const f of addedSorted) {
          sub.appendChild(chunkRow(f, { added: true }));
        }
        if (sharedSorted.length) {
          sub.appendChild(
            el(
              `<div class="ba-pill" style="margin:10px 0 4px">Already in initial load (free): ${sharedSorted.length} files</div>`
            )
          );
          for (const f of sharedSorted) {
            sub.appendChild(chunkRow(f));
          }
        }
        sub.dataset.filled = "1";
      }
    });
    return card;
  }

  function renderInitial() {
    const base = [...baselineClosure()].sort((a, b) => sz(b) - sz(a));
    const t = totals(new Set(base));
    q("initialCards").innerHTML = `
      <div class="ba-card"><div class="k">Files</div><div class="v">${t.files}</div></div>
      <div class="ba-card"><div class="k">Download (brotli)</div><div class="v">${fmt(t.brotli)}</div></div>
      <div class="ba-card"><div class="k">Uncompressed</div><div class="v">${fmt(t.raw)}</div></div>
      <div class="ba-card"><div class="k">Modules</div><div class="v">${base.reduce((n, f) => n + chunks[f].moduleCount, 0)}</div></div>`;
    const list = q("initialList");
    list.innerHTML = "";
    const visible = base.filter(
      (f) =>
        matches(f) ||
        matches(chunks[f].name) ||
        chunks[f].modules.some((m) => matches(m.id))
    );
    if (!visible.length) {
      list.innerHTML = '<div class="ba-empty">No matches.</div>';
    }
    for (const f of visible) {
      list.appendChild(chunkRow(f));
    }
  }

  function renderDynamic() {
    const list = q("dynamicList");
    list.innerHTML = "";
    const dyn = D.dynamicEntrypoints
      .filter((f) => matches(f) || matches(chunks[f].name))
      .sort((a, b) => {
        const base = baselineClosure();
        const aa = [...staticClosure(a)]
          .filter((x) => !base.has(x))
          .reduce((n, x) => n + sz(x), 0);
        const bb = [...staticClosure(b)]
          .filter((x) => !base.has(x))
          .reduce((n, x) => n + sz(x), 0);
        return bb - aa;
      });
    if (!dyn.length) {
      list.innerHTML = '<div class="ba-empty">No dynamic entrypoints.</div>';
    }
    for (const f of dyn) {
      list.appendChild(dynamicCard(f));
    }
  }

  function renderBaseline() {
    const wrap = q("baseline");
    wrap.innerHTML = "";
    for (const f of D.entrypoints) {
      const c = chunks[f];
      const on = baselineSel.has(f);
      const label = el(`
        <label class="${on ? "on" : ""}">
          <input type="checkbox" ${on ? "checked" : ""} />
          ${c.name} <span class="ba-pill">${fmt(c.brotliSize)}</span>
        </label>`);
      label.querySelector("input").addEventListener("change", (e) => {
        if (e.target.checked) {
          baselineSel.add(f);
        } else {
          baselineSel.delete(f);
        }
        renderAll();
      });
      wrap.appendChild(label);
    }
  }

  function renderAll() {
    renderBaseline();
    renderInitial();
    renderDynamic();
  }

  q("meta").textContent = `${D.emberEnv} · ${
    Object.keys(chunks).length
  } chunks · generated ${D.generatedAt}`;
  q("sizeToggle").addEventListener("click", (e) => {
    const b = e.target.closest("button");
    if (!b) {
      return;
    }
    sizeKey = b.dataset.size;
    root
      .querySelectorAll('[data-el="sizeToggle"] button')
      .forEach((x) => x.classList.toggle("on", x === b));
    renderAll();
  });
  q("search").addEventListener("input", (e) => {
    filter = e.target.value.trim().toLowerCase();
    renderInitial();
    renderDynamic();
  });
  renderAll();
}
