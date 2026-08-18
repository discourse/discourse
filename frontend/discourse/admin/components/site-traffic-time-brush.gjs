import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import AdminReportStackedChart from "discourse/admin/components/admin-report-stacked-chart";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";
import { i18n } from "discourse-i18n";

const MINIMUM_RANGE_MS = 60_000;

export default class SiteTrafficTimeBrush extends Component {
  @service a11y;

  @tracked surfaceStyle = null;
  @tracked selectionStyle = null;
  @tracked liveRange = null;
  @tracked hoverStyle = null;
  @tracked hoverLabel = null;

  interactionPlugin = {
    id: "siteTrafficInteraction",
    afterLayout: () => requestAnimationFrame(() => this.syncSurface()),
  };
  #chart;
  #canvas;
  #selectionStart;
  #selectionEnd;
  #surfaceRect;
  #scaleX = 1;
  #dragTarget;
  #pointerId;

  willDestroy() {
    super.willDestroy(...arguments);
    this.#removeCanvasListeners();
    this.#clearActiveDrag();
  }

  get chartOptions() {
    return {
      ...this.args.options,
      chartPlugins: [
        ...(this.args.options?.chartPlugins ?? []),
        this.interactionPlugin,
      ],
      timezone: this.args.timezone,
    };
  }

  get rangeLabel() {
    return this.#rangeLabel(this.args.startDate, this.args.endDate);
  }

  get groupingValue() {
    return this.args.grouping ?? "automatic-current";
  }

  get automaticGroupingLabel() {
    return i18n(
      "admin.site_traffic_explorer.brush.grouping.automatic_with_interval",
      {
        interval: i18n(
          `admin.site_traffic_explorer.brush.grouping.intervals.${this.args.effectiveBucket}`
        ),
      }
    );
  }

  @action
  chartReady(chart) {
    this.#removeCanvasListeners();
    this.#chart = chart;
    this.#canvas = chart.canvas;
    this.#canvas.addEventListener("pointermove", this.updateHover);
    this.#canvas.addEventListener("pointerleave", this.clearHover);
    requestAnimationFrame(() => this.syncSurface());
  }

  @action
  syncSurface() {
    const canvas = this.#chart?.canvas;
    const wrapper = canvas?.closest(".site-traffic-time-brush__chart");
    const chartArea = this.#chart?.chartArea;
    if (!canvas || !wrapper || !chartArea) {
      return;
    }

    const canvasRect = canvas.getBoundingClientRect();
    const wrapperRect = wrapper.getBoundingClientRect();
    const scaleX = canvasRect.width / this.#chart.width;
    const scaleY = canvasRect.height / this.#chart.height;
    const width = (chartArea.right - chartArea.left) * scaleX;
    const height = (chartArea.bottom - chartArea.top) * scaleY;
    if (width <= 0 || height <= 0) {
      return;
    }

    this.#scaleX = scaleX;
    this.surfaceStyle = trustHTML(
      `position: absolute; left: ${canvasRect.left - wrapperRect.left + chartArea.left * scaleX}px; top: ${canvasRect.top - wrapperRect.top + chartArea.top * scaleY}px; width: ${width}px; height: ${height}px; pointer-events: none;`
    );
  }

  @action
  changeGrouping(event) {
    const value = event.target.value;
    this.args.onGroupingChange(
      value === "automatic-current" || value === "" ? null : value
    );
  }

  @action
  startSelection(event) {
    const start = this.args.startDate?.getTime();
    const end = this.args.endDate?.getTime();
    this.#surfaceRect = event.currentTarget
      .querySelector("[data-test-site-traffic-brush-surface]")
      ?.getBoundingClientRect();

    if (
      !Number.isFinite(start) ||
      !Number.isFinite(end) ||
      start >= end ||
      !this.#surfaceRect?.width
    ) {
      return false;
    }

    this.clearHover();
    this.#dragTarget = event.currentTarget;
    this.#pointerId = event.pointerId;
    document.addEventListener("keydown", this.cancelSelectionOnEscape);
    this.#selectionStart = this.#dateAt(event.clientX);
    this.#selectionEnd = this.#selectionStart;
    return true;
  }

  @action
  updateSelection(event) {
    this.#selectionEnd = this.#dateAt(event.clientX);
    this.#updateSelection();
  }

  @action
  finishSelection(_event, info) {
    if (!info.moved) {
      this.cancelSelection();
      return;
    }

    const start = new Date(Math.min(this.#selectionStart, this.#selectionEnd));
    const end = new Date(Math.max(this.#selectionStart, this.#selectionEnd));
    this.cancelSelection();

    if (end - start < MINIMUM_RANGE_MS) {
      return;
    }

    this.args.onSelect(start, end);
    this.a11y.announce(this.#rangeLabel(start, end), "polite");
  }

  @action
  cancelSelection() {
    this.selectionStyle = null;
    this.liveRange = null;
    this.#clearActiveDrag();
  }

  @action
  cancelSelectionOnEscape(event) {
    if (event.key !== "Escape" || !this.#dragTarget) {
      return;
    }

    event.preventDefault();
    const target = this.#dragTarget;
    const pointerId = this.#pointerId;
    this.cancelSelection();
    if (target.hasPointerCapture(pointerId)) {
      target.releasePointerCapture(pointerId);
    }
  }

  @action
  updateHover(event) {
    if (this.selectionStyle || !this.#chart) {
      return;
    }

    const rect = this.#canvas
      ?.closest(".site-traffic-time-brush__chart")
      ?.querySelector("[data-test-site-traffic-brush-surface]")
      ?.getBoundingClientRect();
    if (!rect) {
      return;
    }
    const pointerX =
      (event.clientX - rect.left) / this.#scaleX + this.#chart.chartArea.left;
    const visibleMetas = this.#chart
      .getSortedVisibleDatasetMetas()
      .filter((meta) => meta.data.length);
    const elements = visibleMetas[0]?.data ?? [];
    if (!elements.length) {
      return;
    }

    let nearestIndex = 0;
    for (let index = 1; index < elements.length; index++) {
      if (
        Math.abs(elements[index].x - pointerX) <
        Math.abs(elements[nearestIndex].x - pointerX)
      ) {
        nearestIndex = index;
      }
    }

    const element = elements[nearestIndex];
    const activeElements = visibleMetas
      .filter((meta) => meta.data[nearestIndex])
      .map((meta) => ({ datasetIndex: meta.index, index: nearestIndex }));
    this.#chart.setActiveElements(activeElements);
    this.#chart.tooltip?.setActiveElements(activeElements, {
      x: element.x,
      y: element.y,
    });
    this.#chart.update("none");

    const point =
      this.#chart.data.datasets[activeElements[0]?.datasetIndex]?.data[
        nearestIndex
      ];
    const date = moment.utc(point?.x).tz(this.args.timezone);
    this.hoverStyle = trustHTML(
      `position: absolute; top: 0; bottom: 0; width: 1px; left: ${(element.x - this.#chart.chartArea.left) * this.#scaleX}px; pointer-events: none;`
    );
    this.hoverLabel = i18n("admin.site_traffic_explorer.brush.hover_marker", {
      date: `${date.format("LL")}, ${date.format("LT")}`,
    });
  }

  @action
  clearHover() {
    this.hoverStyle = null;
    this.hoverLabel = null;
    this.#chart?.setActiveElements([]);
    this.#chart?.tooltip?.setActiveElements([], { x: 0, y: 0 });
    this.#chart?.update("none");
  }

  #dateAt(clientX) {
    const boundedX = Math.min(
      Math.max(clientX, this.#surfaceRect.left),
      this.#surfaceRect.right
    );
    const fraction =
      (boundedX - this.#surfaceRect.left) / this.#surfaceRect.width;
    const start = this.args.startDate.getTime();
    return start + fraction * (this.args.endDate.getTime() - start);
  }

  #removeCanvasListeners() {
    this.#canvas?.removeEventListener("pointermove", this.updateHover);
    this.#canvas?.removeEventListener("pointerleave", this.clearHover);
    this.#canvas = null;
  }

  #clearActiveDrag() {
    document.removeEventListener("keydown", this.cancelSelectionOnEscape);
    this.#dragTarget = null;
    this.#pointerId = null;
  }

  #rangeLabel(startDate, endDate) {
    const start = moment(startDate).tz(this.args.timezone);
    const end = moment(endDate).tz(this.args.timezone);
    const endLabel = start.isSame(end, "day")
      ? end.format("LT")
      : `${end.format("LL")}, ${end.format("LT")}`;

    return i18n("admin.site_traffic_explorer.brush.selected_range", {
      start: `${start.format("LL")}, ${start.format("LT")}`,
      end: endLabel,
      timezone: start.format("z"),
    });
  }

  #updateSelection() {
    const start = Math.min(this.#selectionStart, this.#selectionEnd);
    const end = Math.max(this.#selectionStart, this.#selectionEnd);
    const range = this.args.endDate - this.args.startDate;
    const left =
      ((start - this.args.startDate) / range) * this.#surfaceRect.width;
    const width = ((end - start) / range) * this.#surfaceRect.width;

    this.selectionStyle = trustHTML(
      `position: absolute; top: 0; bottom: 0; left: ${left}px; width: ${width}px; pointer-events: none;`
    );
    this.liveRange = this.#rangeLabel(new Date(start), new Date(end));
  }

  <template>
    <div class="site-traffic-time-brush">
      <div class="site-traffic-time-brush__controls">
        <span
          class="site-traffic-time-brush__instructions"
          id="site-traffic-brush-instructions"
        >
          {{i18n "admin.site_traffic_explorer.brush.instructions"}}
        </span>
        <label class="site-traffic-time-brush__grouping">
          <span>{{i18n
              "admin.site_traffic_explorer.brush.grouping.label"
            }}</span>
          <select
            aria-label={{i18n
              "admin.site_traffic_explorer.brush.grouping.label"
            }}
            value={{this.groupingValue}}
            {{on "change" this.changeGrouping}}
          >
            {{#unless @grouping}}
              <option value="automatic-current" selected hidden>
                {{this.automaticGroupingLabel}}
              </option>
            {{/unless}}
            <option value="" selected={{eq this.groupingValue ""}}>
              {{i18n
                "admin.site_traffic_explorer.brush.grouping.options.automatic"
              }}
            </option>
            <option value="hour" selected={{eq this.groupingValue "hour"}}>
              {{i18n "admin.site_traffic_explorer.brush.grouping.options.hour"}}
            </option>
            <option value="day" selected={{eq this.groupingValue "day"}}>
              {{i18n "admin.site_traffic_explorer.brush.grouping.options.day"}}
            </option>
          </select>
        </label>
        {{#if this.liveRange}}
          <span
            class="site-traffic-time-brush__range"
            aria-live="polite"
            data-test-site-traffic-brush-live-range
          >{{this.liveRange}}</span>
        {{else if @hasPreciseRange}}
          <span
            class="site-traffic-time-brush__range"
            data-test-site-traffic-precise-range
          >{{this.rangeLabel}}</span>
          <DButton
            class="btn-default btn-small site-traffic-time-brush__reset"
            @action={{@onClear}}
            @label="admin.site_traffic_explorer.brush.reset"
            data-test-site-traffic-reset-range
          />
        {{/if}}
      </div>

      <div
        class="site-traffic-time-brush__chart"
        {{dPointerDrag
          onDragStart=this.startSelection
          onDrag=this.updateSelection
          onDragEnd=this.finishSelection
          onDragCancel=this.cancelSelection
          threshold=6
          touchAction="pan-y"
          draggingClass="--selecting"
        }}
      >
        <AdminReportStackedChart
          @model={{@model}}
          @options={{this.chartOptions}}
          @onChartReady={{this.chartReady}}
          class="db-section__traffic-chart-canvas"
        />
        {{#if this.surfaceStyle}}
          <div
            class="site-traffic-time-brush__surface"
            style={{this.surfaceStyle}}
            aria-describedby="site-traffic-brush-instructions"
            data-test-site-traffic-brush-surface
          >
            {{#if this.hoverStyle}}
              <div
                class="site-traffic-time-brush__hover-marker"
                style={{this.hoverStyle}}
                role="img"
                aria-label={{this.hoverLabel}}
                data-test-site-traffic-hover-marker
              ></div>
            {{/if}}
            {{#if this.selectionStyle}}
              <div
                class="site-traffic-time-brush__selection"
                style={{this.selectionStyle}}
                data-test-site-traffic-brush-selection
              ></div>
            {{/if}}
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
