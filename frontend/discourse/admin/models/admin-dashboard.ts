import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

/** A dashboard section; plugin loaders supply arbitrary `data`, and a failed section sends `error`. */
export interface AdminDashboardSection {
  id: string;
  data?: unknown;
  error?: boolean;
}

export interface AdminDashboardProblem {
  id: number;
  priority: "low" | "high";
  message: string;
  identifier: string;
}

/** Each loader populates a different subset. */
export interface AdminDashboardFields {
  sections?: AdminDashboardSection[];
  configuration?: { sections: { id: string; visible: boolean }[] };
  problems?: AdminDashboardProblem[];
  loaded?: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface AdminDashboard extends AdminDashboardFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class AdminDashboard extends EmberObject {
  static async fetch({
    startDate,
    endDate,
  }: { startDate?: Date; endDate?: Date } = {}): Promise<AdminDashboard> {
    const data: { start_date?: string; end_date?: string } = {};
    if (startDate) {
      data.start_date = moment(startDate).format("YYYY-MM-DD");
    }
    if (endDate) {
      data.end_date = moment(endDate).format("YYYY-MM-DD");
    }

    const json = await ajax<AdminDashboardFields>("/admin/dashboard.json", {
      data,
    });
    const model = AdminDashboard.create();

    model.setProperties({
      sections: json.sections,
      configuration: json.configuration,
      problems: json.problems,
    });

    return model;
  }

  static async fetchProblems(): Promise<AdminDashboard> {
    const json = await ajax<{ problems: AdminDashboardProblem[] }>(
      "/admin/dashboard/problems.json",
      {
        type: "POST",
      }
    );
    const model = AdminDashboard.create(json);

    model.set("loaded", true);

    return model;
  }
}

declare const moment: typeof import("moment");
