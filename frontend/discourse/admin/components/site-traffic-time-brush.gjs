import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import AdminReportStackedChart from "discourse/admin/components/admin-report-stacked-chart";
import DButton from "discourse/ui-kit/d-button";
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";
import { i18n } from "discourse-i18n";

const MINIMUM_RANGE_MS = 60_000;

export default class SiteTrafficTimeBrush extends Component {
  @service a11y;

  @tracked selectionStyle = null;

  #canvasRect;
  #chart;
  #wrapperRect;
  #selectionStart;
  #selectionEnd;

  get rangeLabel() {
    return this.#rangeLabel(this.args.startDate, this.args.endDate);
  }

  get groupingLabel() {
    return i18n(
      `admin.site_traffic_explorer.brush.grouping.${this.args.bucket ?? "day"}`
    );
  }

  @action
  chartReady(chart) {
    this.#chart = chart;
  }

  @action
  startSelection(event) {
    const canvas = event.target.closest("canvas.chart-canvas");
    const wrapper = canvas?.closest(".site-traffic-time-brush__chart");
    const start = this.args.startDate?.getTime();
    const end = this.args.endDate?.getTime();

    if (
      !canvas ||
      !wrapper ||
      this.#chart?.canvas !== canvas ||
      !start ||
      !end ||
      start >= end
    ) {
      return false;
    }

    const canvasRect = canvas.getBoundingClientRect();
    const chartArea = this.#chart.chartArea;
    this.#canvasRect = {
      left: canvasRect.left + chartArea.left,
      right: canvasRect.left + chartArea.right,
      top: canvasRect.top + chartArea.top,
      bottom: canvasRect.top + chartArea.bottom,
      width: chartArea.right - chartArea.left,
    };
    this.#wrapperRect = wrapper.getBoundingClientRect();
    if (
      this.#canvasRect.width <= 0 ||
      this.#wrapperRect.width <= 0 ||
      event.clientY < this.#canvasRect.top ||
      event.clientY > this.#canvasRect.bottom
    ) {
      return false;
    }

    this.#selectionStart = this.#dateAt(event.clientX);
    this.#selectionEnd = this.#selectionStart;
    return true;
  }

  @action
  updateSelection(event) {
    this.#selectionEnd = this.#dateAt(event.clientX);
    this.#updateSelectionStyle();
  }

  @action
  finishSelection(_event, info) {
    if (!info.moved) {
      this.cancelSelection();
      return;
    }

    const start = new Date(Math.min(this.#selectionStart, this.#selectionEnd));
    const end = new Date(Math.max(this.#selectionStart, this.#selectionEnd));
    this.selectionStyle = null;

    if (end - start < MINIMUM_RANGE_MS) {
      return;
    }

    this.args.onSelect(start, end);
    this.a11y.announce(this.#rangeLabel(start, end), "polite");
  }

  @action
  cancelSelection() {
    this.selectionStyle = null;
  }

  #dateAt(clientX) {
    const boundedX = Math.min(
      Math.max(clientX, this.#canvasRect.left),
      this.#canvasRect.right
    );
    const fraction =
      (boundedX - this.#canvasRect.left) / this.#canvasRect.width;
    const start = this.args.startDate.getTime();

    return start + fraction * (this.args.endDate.getTime() - start);
  }

  #rangeLabel(startDate, endDate) {
    const start = moment.utc(startDate);
    const end = moment.utc(endDate);
    const endLabel = start.isSame(end, "day")
      ? end.format("LT")
      : end.format("lll");

    return i18n("admin.site_traffic_explorer.brush.selected_range", {
      start: start.format("lll"),
      end: endLabel,
    });
  }

  #updateSelectionStyle() {
    const startX = Math.min(this.#selectionStart, this.#selectionEnd);
    const endX = Math.max(this.#selectionStart, this.#selectionEnd);
    const rangeMs = this.args.endDate - this.args.startDate;
    const canvasStartX = this.#canvasRect.left - this.#wrapperRect.left;
    const selectedStartX =
      canvasStartX +
      ((startX - this.args.startDate.getTime()) / rangeMs) *
        this.#canvasRect.width;
    const selectedEndX =
      canvasStartX +
      ((endX - this.args.startDate.getTime()) / rangeMs) *
        this.#canvasRect.width;
    const top = this.#canvasRect.top - this.#wrapperRect.top;
    const right = this.#wrapperRect.width - selectedEndX;
    const bottom = this.#wrapperRect.bottom - this.#canvasRect.bottom;

    this.selectionStyle = trustHTML(
      `clip-path: inset(${top}px ${right}px ${bottom}px ${selectedStartX}px);`
    );
  }

  <template>
    <div class="site-traffic-time-brush">
      <div class="site-traffic-time-brush__controls">
        <span class="site-traffic-time-brush__instructions">
          {{i18n "admin.site_traffic_explorer.brush.instructions"}}
        </span>
        <span class="site-traffic-time-brush__grouping">
          {{this.groupingLabel}}
        </span>
        {{#if @hasPreciseRange}}
          <span
            class="site-traffic-time-brush__range"
            data-test-site-traffic-precise-range
          >
            {{this.rangeLabel}}
          </span>
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
          @options={{@options}}
          @onChartReady={{this.chartReady}}
          class="db-section__traffic-chart-canvas"
        />
        {{#if this.selectionStyle}}
          <div
            class="site-traffic-time-brush__selection"
            style={{this.selectionStyle}}
            data-test-site-traffic-brush-selection
          ></div>
        {{/if}}
      </div>
    </div>
  </template>
}
