import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import { i18n } from "discourse-i18n";

// Motion adapted from thinking-orbs by Jakub Antalik (MIT).

const REDUCED_MOTION_QUERY = "(prefers-reduced-motion: reduce)";
const SVG_NS = "http://www.w3.org/2000/svg";
const DEFAULT_PALETTE = ["#e2212e", "#f15d22", "#fff8ac", "#00ae58", "#04a9e2"];

const SMALL_LANES = 2;
const SMALL_DOTS_PER_LANE = 11;

// Neutral "glass" outline for the lava lamp capsule; the small variant is
// heavier so it survives one-pixel rendering.
const GLASS_STROKE = "rgba(247, 248, 250, 0.16)";
const GLASS_STROKE_SMALL = "rgba(247, 248, 250, 0.4)";

// Themes restyle the indicator through the matching custom properties rather
// than by reaching into the render loops.
function readPalette(element) {
  const styles = window.getComputedStyle(element);

  return DEFAULT_PALETTE.map(
    (fallback, index) =>
      styles.getPropertyValue(`--d-thinking-color-${index + 1}`).trim() ||
      fallback
  );
}

/**
 * Calls `render(seconds)` every animation frame. When the user prefers reduced
 * motion a single static frame is drawn instead, and the switch is honoured
 * live if the preference changes.
 *
 * @param {(seconds: number) => void} render
 * @returns {{ refresh: () => void, stop: () => void }}
 */
function startLoop(render) {
  const reducedMotion = window.matchMedia(REDUCED_MOTION_QUERY);
  let frame = 0;

  const tick = (time) => {
    render(time / 1000);
    frame = requestAnimationFrame(tick);
  };

  const sync = () => {
    cancelAnimationFrame(frame);
    render(performance.now() / 1000);

    if (!reducedMotion.matches) {
      frame = requestAnimationFrame(tick);
    }
  };

  sync();
  reducedMotion.addEventListener("change", sync);

  return {
    refresh: () => render(performance.now() / 1000),
    stop: () => {
      cancelAnimationFrame(frame);
      reducedMotion.removeEventListener("change", sync);
    },
  };
}

// A thick ring of shimmering dots carrying travelling ripples, wrapped around a
// faint drifting dot field.
function drawRing(ctx, palette, size, t) {
  const ink = size / 440;
  const centerX = size * 0.5;
  const centerY = size * 0.485;
  const outer = size * 0.33;
  const lanes = 7;
  const dotsPerLane = 104;
  const fieldDots = 90;

  ctx.clearRect(0, 0, size, size);

  for (let lane = 0; lane < lanes; lane++) {
    const laneDistance = lane - (lanes - 1) / 2;
    const laneOffset = laneDistance * size * 0.0105;

    for (let i = 0; i < dotsPerLane; i++) {
      const angle = (i / dotsPerLane) * Math.PI * 2;
      const wave =
        0.115 * Math.sin(angle * 3 - t * 1.7 + lane * 0.24) +
        0.055 * Math.sin(angle * 5 + t * 1.13 - lane * 0.17) +
        0.022 * Math.sin(angle * 11 - t * 2.1);
      const radius = outer * (0.88 + wave) + laneOffset;
      const shimmer = 0.5 + 0.5 * Math.sin(angle * 7 - t * 2.65 + lane * 0.9);
      const spark = Math.pow(shimmer, 5);
      const dotRadius =
        (1.25 + spark * 2.2) * ink * (1 - Math.abs(laneDistance) * 0.042);

      ctx.beginPath();
      ctx.arc(
        centerX + Math.cos(angle) * radius,
        centerY + Math.sin(angle) * radius,
        dotRadius,
        0,
        Math.PI * 2
      );
      ctx.globalAlpha = 0.28 + shimmer * 0.58;
      ctx.fillStyle = palette[(i + lane * 13) % palette.length];

      if (spark > 0.68) {
        ctx.shadowColor = ctx.fillStyle;
        ctx.shadowBlur = 9;
      }

      ctx.fill();
      ctx.shadowBlur = 0;
    }
  }

  for (let i = 0; i < fieldDots; i++) {
    // golden-angle spacing keeps the field evenly scattered
    const angle = i * 2.399963;
    const radius = outer * 0.78 * Math.sqrt((i + 0.5) / fieldDots);
    const drift = 1 + 0.025 * Math.sin(t * 1.2 + i * 0.73);

    ctx.beginPath();
    ctx.arc(
      centerX + Math.cos(angle + t * 0.025) * radius * drift,
      centerY + Math.sin(angle + t * 0.025) * radius * drift,
      0.72 * ink,
      0,
      Math.PI * 2
    );
    ctx.globalAlpha = 0.09 + 0.07 * Math.sin(i * 1.7 + t);
    ctx.fillStyle = palette[i % palette.length];
    ctx.fill();
  }

  ctx.globalAlpha = 1;
}

// Deterministic hash used to time the lava lamp's pseudo-random wobbles
// without any per-frame allocation.
function tapeHash(a, b = 0) {
  const value = Math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
  return value - Math.floor(value);
}

// A seventies lava lamp: molten blobs wobble, squish, rise, and sink inside a
// glass capsule lit from below, with tiny bubbles drifting upward.
function drawLava(ctx, palette, size, t) {
  const ink = size / 440;
  const centerX = size * 0.5;
  const centerY = size * 0.49;
  const glassWidth = size * 0.21;
  const glassHeight = size * 0.385;

  ctx.clearRect(0, 0, size, size);
  ctx.save();

  ctx.strokeStyle = GLASS_STROKE;
  ctx.lineWidth = 1.4 * ink;
  ctx.beginPath();
  ctx.roundRect(
    centerX - glassWidth,
    centerY - glassHeight,
    glassWidth * 2,
    glassHeight * 2,
    glassWidth
  );
  ctx.stroke();

  ctx.beginPath();
  ctx.roundRect(
    centerX - glassWidth + 2 * ink,
    centerY - glassHeight + 2 * ink,
    (glassWidth - 2 * ink) * 2,
    (glassHeight - 2 * ink) * 2,
    glassWidth - 2 * ink
  );
  ctx.clip();

  const glow = ctx.createRadialGradient(
    centerX,
    centerY + glassHeight,
    0,
    centerX,
    centerY + glassHeight,
    glassHeight * 1.1
  );
  glow.addColorStop(0, palette[1]);
  glow.addColorStop(1, "transparent");
  ctx.globalAlpha = 0.3;
  ctx.fillStyle = glow;
  ctx.fillRect(
    centerX - glassWidth,
    centerY - glassHeight,
    glassWidth * 2,
    glassHeight * 2
  );
  ctx.globalAlpha = 1;

  for (let blob = 0; blob < 7; blob++) {
    const speed = 0.16 + tapeHash(blob, 1) * 0.13;
    const phase = blob * 0.93 + tapeHash(blob, 2) * 0.8;
    const radius = size * (0.05 + tapeHash(blob, 3) * 0.05);
    const x =
      centerX +
      Math.sin(t * speed * 0.57 + phase * 1.7) *
        (glassWidth - radius - 6 * ink) *
        0.8;
    const y =
      centerY + Math.sin(t * speed + phase) * (glassHeight - radius - 8 * ink);
    const squish = 1 + 0.16 * Math.cos(t * speed + phase);
    const color = palette[blob % palette.length];

    ctx.beginPath();
    for (let i = 0; i <= 44; i++) {
      const angle = (i / 44) * Math.PI * 2;
      const wobble =
        1 +
        0.09 * Math.sin(angle * 3 + t * 0.9 + blob * 2.3) +
        0.05 * Math.sin(angle * 5 - t * 1.3 + blob);
      const pointX = x + Math.cos(angle) * radius * wobble;
      const pointY = y + Math.sin(angle) * radius * wobble * squish;

      if (i === 0) {
        ctx.moveTo(pointX, pointY);
      } else {
        ctx.lineTo(pointX, pointY);
      }
    }
    ctx.closePath();
    ctx.fillStyle = color;
    ctx.globalAlpha = 0.85;
    ctx.shadowColor = color;
    ctx.shadowBlur = 18;
    ctx.fill();
    ctx.shadowBlur = 0;
  }

  for (let bubble = 0; bubble < 10; bubble++) {
    const rise =
      (t * (0.05 + tapeHash(bubble, 5) * 0.06) + tapeHash(bubble, 6)) % 1;

    ctx.beginPath();
    ctx.arc(
      centerX + (tapeHash(bubble, 7) - 0.5) * glassWidth * 1.5,
      centerY + glassHeight - rise * glassHeight * 2,
      0.9 * ink * (1 + tapeHash(bubble, 8)),
      0,
      Math.PI * 2
    );
    ctx.globalAlpha = 0.35 * (1 - rise);
    ctx.fillStyle = palette[2];
    ctx.fill();
  }

  ctx.restore();
  ctx.globalAlpha = 1;
}

// Five thick ribbon streams — one per palette color — weave across the frame
// like seventies supergraphic stripes, carrying bright travelling packets.
function drawRibbons(ctx, palette, size, t) {
  const ink = size / 440;
  const centerY = size * 0.49;

  const ribbonY = (u, ribbon) =>
    centerY +
    (ribbon - 2) * size * 0.082 +
    size * 0.115 * Math.sin(u * 5.1 - t * 0.8 + ribbon * 1.26) +
    size * 0.038 * Math.sin(u * 9.3 + t * 1.35 - ribbon * 0.8);

  ctx.clearRect(0, 0, size, size);
  ctx.save();
  ctx.globalCompositeOperation = "lighter";
  ctx.lineCap = "round";
  ctx.lineJoin = "round";

  for (let ribbon = 0; ribbon < 5; ribbon++) {
    const path = new Path2D();

    for (let i = 0; i <= 110; i++) {
      const u = i / 110;
      const x = size * 0.04 + u * size * 0.92;
      const y = ribbonY(u, ribbon);

      if (i === 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    ctx.strokeStyle = palette[ribbon];
    ctx.globalAlpha = 0.12;
    ctx.lineWidth = 15 * ink;
    ctx.shadowColor = palette[ribbon];
    ctx.shadowBlur = 17;
    ctx.stroke(path);
    ctx.globalAlpha = 0.8;
    ctx.lineWidth = 4.2 * ink;
    ctx.shadowBlur = 7;
    ctx.stroke(path);

    for (let packet = 0; packet < 2; packet++) {
      const u = (t * (0.08 + packet * 0.03) + ribbon * 0.19 + packet * 0.5) % 1;

      ctx.beginPath();
      ctx.arc(
        size * 0.04 + u * size * 0.92,
        ribbonY(u, ribbon),
        2.3 * ink,
        0,
        Math.PI * 2
      );
      ctx.globalAlpha = 0.95;
      ctx.fillStyle = palette[(ribbon + packet + 2) % palette.length];
      ctx.shadowColor = ctx.fillStyle;
      ctx.shadowBlur = 12;
      ctx.fill();
      ctx.shadowBlur = 0;
    }
  }

  ctx.restore();
  ctx.globalAlpha = 1;
}

function createSvgElement(parent, name, attributes) {
  const element = document.createElementNS(SVG_NS, name);

  for (const [key, value] of Object.entries(attributes)) {
    element.setAttribute(key, value);
  }

  parent.append(element);
  return element;
}

function svgPathFrom(points) {
  return points
    .map(
      ([x, y], index) => `${index ? "L" : "M"}${x.toFixed(2)} ${y.toFixed(2)}`
    )
    .join("");
}

// Each small builder appends its elements to the (initially empty) svg and
// returns the per-frame update; the modifier empties the svg again on
// teardown.

// The same ripple and shimmer motion as the canvas ring, reduced to a crisp
// two-lane ring of SVG circles in a 20x20 viewBox.
function buildSmallRing(svg, palette) {
  const center = 10;
  const dots = [];

  for (let lane = 0; lane < SMALL_LANES; lane++) {
    for (let i = 0; i < SMALL_DOTS_PER_LANE; i++) {
      dots.push({
        element: createSvgElement(svg, "circle", {
          fill: palette[(i + lane * 13) % palette.length],
        }),
        lane,
        index: i,
      });
    }
  }

  return (t) => {
    for (const { element, lane, index } of dots) {
      const angle = (index / SMALL_DOTS_PER_LANE) * Math.PI * 2;
      const wave =
        0.13 * Math.sin(angle * 3 - t * 1.7 + lane * 0.24) +
        0.055 * Math.sin(angle * 5 + t * 1.13 - lane * 0.17);
      const radius = 6.4 * (1 + wave) + (lane - 0.5) * 1.7;
      const shimmer = 0.5 + 0.5 * Math.sin(angle * 7 - t * 2.65 + lane * 0.9);

      element.setAttribute(
        "cx",
        (center + Math.cos(angle) * radius).toFixed(2)
      );
      element.setAttribute(
        "cy",
        (center + Math.sin(angle) * radius).toFixed(2)
      );
      element.setAttribute("r", (0.6 + shimmer * 0.6).toFixed(2));
      element.setAttribute("opacity", (0.5 + shimmer * 0.5).toFixed(2));
    }
  };
}

let lavaClipSequence = 0;

// Three blobs drifting inside an outlined glass capsule.
function buildSmallLava(svg, palette) {
  const center = 10;
  const clipId = `d-thinking-lava-clip-${++lavaClipSequence}`;

  createSvgElement(svg, "rect", {
    x: 6,
    y: 1.5,
    width: 8,
    height: 17,
    rx: 4,
    fill: "none",
    stroke: GLASS_STROKE_SMALL,
    "stroke-width": 1,
  });

  const clipPath = createSvgElement(svg, "clipPath", { id: clipId });
  createSvgElement(clipPath, "rect", {
    x: 6.5,
    y: 2,
    width: 7,
    height: 16,
    rx: 3.5,
  });

  const group = createSvgElement(svg, "g", { "clip-path": `url(#${clipId})` });
  const blobs = [0, 1, 2].map((blob) =>
    createSvgElement(group, "circle", {
      fill: palette[[0, 1, 3][blob]],
      r: 1.7 + blob * 0.35,
      opacity: 0.95,
    })
  );

  return (t) => {
    blobs.forEach((element, blob) => {
      element.setAttribute(
        "cx",
        (center + Math.sin(t * 0.3 + blob * 2.4) * 1.4).toFixed(2)
      );
      element.setAttribute(
        "cy",
        (center + Math.sin(t * (0.5 + blob * 0.17) + blob * 2.1) * 5.2).toFixed(
          2
        )
      );
    });
  };
}

// Five one-pixel ribbon strokes weaving across the viewBox.
function buildSmallRibbons(svg, palette) {
  const center = 10;
  const ribbons = [0, 1, 2, 3, 4].map((ribbon) =>
    createSvgElement(svg, "path", {
      fill: "none",
      stroke: palette[ribbon],
      "stroke-width": 1.1,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      opacity: 0.9,
    })
  );

  return (t) => {
    ribbons.forEach((element, ribbon) => {
      const points = [];

      for (let i = 0; i <= 24; i++) {
        const u = i / 24;
        points.push([
          1 + u * 18,
          center +
            (ribbon - 2) * 1.9 +
            2.1 * Math.sin(u * 5.1 - t * 0.8 + ribbon * 1.26),
        ]);
      }

      element.setAttribute("d", svgPathFrom(points));
    });
  };
}

const RENDERERS = {
  breathing: { large: drawRing, small: buildSmallRing },
  lava: { large: drawLava, small: buildSmallLava },
  ribbons: { large: drawRibbons, small: buildSmallRibbons },
};

/**
 * Animated indicator for work in progress, in two sizes and three motion
 * styles:
 *
 * ```hbs
 * <DThinking />                 {{! 420px canvas ring }}
 * <DThinking @size="small" />   {{! 20x20 inline SVG ring }}
 * <DThinking @type="lava" />    {{! seventies lava lamp }}
 * <DThinking @type="ribbons" /> {{! woven ribbon streams }}
 * ```
 *
 * @param {"large" | "small"} [size="large"] rendering variant
 * @param {"breathing" | "lava" | "ribbons"} [type="breathing"] motion style
 * @param {string} [label] accessible label; defaults to a generic "Thinking…"
 */
export default class DThinking extends Component {
  setupCanvas = modifier((canvas) => {
    const ctx = canvas.getContext("2d");
    const palette = readPalette(canvas);
    const draw = RENDERERS[this.type].large;
    let size = 0;

    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      size = Math.round(canvas.getBoundingClientRect().width);
      canvas.width = Math.round(size * dpr);
      canvas.height = Math.round(size * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };

    resize();

    const loop = startLoop((t) => draw(ctx, palette, size, t));
    const observer = new ResizeObserver(() => {
      resize();
      loop.refresh();
    });
    observer.observe(canvas);

    return () => {
      observer.disconnect();
      loop.stop();
    };
  });

  setupSvg = modifier((svg) => {
    const update = RENDERERS[this.type].small(svg, readPalette(svg));
    const loop = startLoop(update);

    return () => {
      loop.stop();
      svg.replaceChildren();
    };
  });

  get isSmall() {
    return this.args.size === "small";
  }

  get type() {
    return RENDERERS[this.args.type] ? this.args.type : "breathing";
  }

  get label() {
    return this.args.label ?? i18n("thinking.label");
  }

  <template>
    {{#if this.isSmall}}
      <svg
        class="d-thinking d-thinking--small d-thinking--{{this.type}}"
        viewBox="0 0 20 20"
        role="img"
        aria-label={{this.label}}
        {{this.setupSvg}}
        ...attributes
      ></svg><span class="d-thinking--label-small">{{this.label}}</span>
    {{else}}
      <canvas
        class="d-thinking d-thinking--large d-thinking--{{this.type}}"
        role="img"
        aria-label={{this.label}}
        {{this.setupCanvas}}
        ...attributes
      ></canvas>
    {{/if}}
  </template>
}
