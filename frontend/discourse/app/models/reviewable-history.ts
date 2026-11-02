import RestModel from "discourse/models/rest";
import type User from "discourse/models/user";

export const CLAIMED = 3 as const;
export const UNCLAIMED = 4 as const;

/** Server histories side-loaded with reviewables; synthetic timeline entries are separate. */
export interface ReviewableHistoryFields {
  id: number;
  reviewable_history_type: number;
  status: number;
  created_at: string;
  created_by_id?: number;
  /** Hydration sets missing side-loaded creators to null. */
  created_by?: User | null;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface ReviewableHistory extends ReviewableHistoryFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class ReviewableHistory extends RestModel {}
