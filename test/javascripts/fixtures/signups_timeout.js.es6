import signups from "fixtures/signups";

const signupsTimeoutKey = "/admin/reports/signups_timeout";
const signupsKey = "/admin/reports/signups";

let fixture = {};

fixture[signupsTimeoutKey] = JSON.parse(JSON.stringify(signups[signupsKey]));
fixture[signupsTimeoutKey].report.error = "timeout";

export default fixture;
