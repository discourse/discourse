import sinon from "sinon";

const PARIS = "Europe/Paris";

export default function freezeTime({ date, timezone }, cb) {
  date = date || "2020-01-22 10:34";
  const newTimezone = timezone || PARIS;
  const previousZone = moment.tz.guess();
  const now = moment.tz(date, newTimezone).valueOf();

  sinon.useFakeTimers(now);
  sinon.stub(moment.tz, "guess");
  moment.tz.guess.returns(newTimezone);
  moment.tz.setDefault(newTimezone);

  cb();

  moment.tz.guess.returns(previousZone);
  moment.tz.setDefault(previousZone);
  sinon.restore();
}
