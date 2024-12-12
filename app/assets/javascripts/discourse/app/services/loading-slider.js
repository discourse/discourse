import { tracked } from "@glimmer/tracking";
import Evented from "@ember/object/evented";
import { cancel, later, schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { bind } from "discourse-common/utils/decorators";

const STORE_LOADING_TIMES = 5;
const DEFAULT_LOADING_TIME = 0.3;
const MIN_LOADING_TIME = 0.2;

const STILL_LOADING_DURATION = 2;

class RollingAverage {
  @tracked average;
  #values = [];
  #i = 0;
  #size;

  constructor(size, initialAverage) {
    this.#size = size;
    this.average = initialAverage;
  }

  record(value) {
    this.#values[this.#i] = value;
    this.#i = (this.#i + 1) % this.#size;
    this.average =
      this.#values.reduce((p, c) => p + c, 0) / this.#values.length;
  }
}

class ScheduleManager {
  #scheduled = [];

  cancelAll() {
    this.#scheduled.forEach((s) => cancel(s));
    this.#scheduled = [];
  }

  schedule() {
    this.#scheduled.push(schedule(...arguments));
  }

  later() {
    this.#scheduled.push(later(...arguments));
  }
}

class Timer {
  #startedAt;

  start() {
    this.#startedAt = Date.now();
  }

  stop() {
    return (Date.now() - this.#startedAt) / 1000;
  }
}

@disableImplicitInjections
export default class LoadingSlider extends Service.extend(Evented) {
  @service siteSettings;
  @tracked loading = false;
  @tracked stillLoading = false;

  rollingAverage = new RollingAverage(
    STORE_LOADING_TIMES,
    DEFAULT_LOADING_TIME
  );

  scheduleManager = new ScheduleManager();

  timer = new Timer();

  get mode() {
    return this.siteSettings.page_loading_indicator;
  }

  get averageLoadingDuration() {
    return this.rollingAverage.average;
  }

  transitionStarted() {
    if (this.loading) {
      // Nested transition
      return;
    }

    this.timer.start();
    this.loading = true;
    this.trigger("stateChanged", true);

    this.scheduleManager.cancelAll();

    this.scheduleManager.later(
      this.setStillLoading,
      STILL_LOADING_DURATION * 1000
    );
  }

  @bind
  transitionEnded() {
    if (!this.loading) {
      return;
    }

    let duration = this.timer.stop();
    if (duration < MIN_LOADING_TIME) {
      duration = MIN_LOADING_TIME;
    }
    this.rollingAverage.record(duration);

    this.loading = false;
    this.stillLoading = false;
    this.trigger("stateChanged", false);

    this.scheduleManager.cancelAll();
    this.scheduleManager.schedule("render", this.removeClasses);
  }

  @bind
  setStillLoading() {
    this.stillLoading = true;
    this.scheduleManager.schedule("render", this.addStillLoadingClass);
  }

  @bind
  addStillLoadingClass() {
    document.body.classList.add("still-loading");
  }

  @bind
  removeClasses() {
    document.body.classList.remove("loading", "still-loading");
  }
}
