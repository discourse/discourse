import { applyFlaggedProperties } from 'discourse/controllers/header';

export default {
  name: 'apply-flagged-properties',
  after: 'map-routes',
  initialize: applyFlaggedProperties
};
