import { applyFlaggedProperties } from 'discourse/controllers/header';

export default {
  name: 'apply-flagged-properties',
  after: 'register-discourse-location',
  initialize: applyFlaggedProperties
};
