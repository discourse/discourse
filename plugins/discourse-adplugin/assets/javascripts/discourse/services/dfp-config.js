import { later } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import Site from "discourse/models/site";

const MAP_URL = "/ad_plugin/dfp_category_settings";
const JITTER_MS = 3_000;

export default class DfpConfig extends Service {
  @service currentUser;

  #version = 0;
  #needsFetch = false;
  #scheduled = false;
  #inFlight = null;

  // The signal carries only the public map (safe for everyone) and a `secure`
  // flag. For anonymous viewers, or when no private config exists, that public
  // map is the complete answer and is applied directly with no request. When
  // private config exists, logged-in viewers must fetch their own map: the
  // public set is a *subset* of theirs, so replacing it would drop settings for
  // private categories they can see. Category visibility is per-group, so staff
  // status is not a valid proxy for who needs to fetch.
  onSignal({ public: publicMap, secure }) {
    this.#version++;

    if (secure && this.currentUser) {
      this.#needsFetch = true;
      this.#scheduleFetch();
    } else {
      this.#needsFetch = false;
      Site.currentProp("dfp_category_settings", publicMap);
    }
  }

  #scheduleFetch() {
    if (this.#inFlight || this.#scheduled) {
      return;
    }
    this.#scheduled = true;
    const wait = Math.floor(Math.random() * JITTER_MS);
    later(
      this,
      () => {
        this.#scheduled = false;
        if (this.#needsFetch) {
          this.#runFetch();
        }
      },
      wait
    );
  }

  #runFetch() {
    const startedAtVersion = this.#version;

    this.#inFlight = ajax(MAP_URL)
      .then((map) => {
        // Drop responses that began before the latest signal; a newer signal has
        // already advanced state (e.g. removed a now-deleted category), and this
        // older response must not resurrect it.
        if (startedAtVersion === this.#version) {
          Site.currentProp("dfp_category_settings", map);
        }
      })
      .catch(() => {
        // ignore; the next page load re-reads the per-scope :site value
      })
      .finally(() => {
        this.#inFlight = null;
        if (this.#needsFetch && startedAtVersion !== this.#version) {
          this.#scheduleFetch();
        }
      });
  }
}
