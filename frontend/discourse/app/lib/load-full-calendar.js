import { waitForPromise } from "@ember/test-waiters";

export default async function loadFullCalendar() {
  const promise = import("discourse/static/full-calendar-bundle");
  waitForPromise(promise);
  return await promise;
}
