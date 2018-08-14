import signups from "fixtures/signups";

const signupsExceptionKey = "/admin/reports/signups_exception";
const signupsKey = "/admin/reports/signups";

let fixture = {};

fixture[signupsExceptionKey] = JSON.parse(JSON.stringify(signups[signupsKey]));
fixture[signupsExceptionKey].report.error = "exception";

export default fixture;
