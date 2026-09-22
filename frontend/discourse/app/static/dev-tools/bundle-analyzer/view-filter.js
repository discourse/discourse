import { tracked } from "@glimmer/tracking";

// What the reader has asked to see. One instance is shared by every graph on
// screen — core's, each plugin's — so one toggle governs the rows and the
// totals above them alike, and the two tabs never disagree.
export default class ViewFilter {
  @tracked onlyLoaded = true;
}
