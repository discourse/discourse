import RestModel from "discourse/models/rest";

export const CLAIMED = 3;
export const UNCLAIMED = 4;
export const DSA_CLASSIFIED = 5;

export default class ReviewableHistory extends RestModel {}
