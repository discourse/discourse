import { ajax } from "discourse/lib/ajax";

export async function loadDashboardReports({ items, filters }) {
  if (!items?.length) {
    return new Map();
  }

  const response = await ajax("/admin/dashboard/reports/bulk", {
    type: "POST",
    contentType: "application/json",
    data: JSON.stringify({ items, filters }),
  });

  const map = new Map();
  for (const entry of response.items) {
    map.set(entry.key, entry.data);
  }
  return map;
}
