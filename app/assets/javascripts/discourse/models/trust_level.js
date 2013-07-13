/**
  Represents a user's trust level in the system

  @class TrustLevel
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.TrustLevel = Discourse.Model.extend({
  detailedName: Discourse.computed.fmt('id', 'name', '%@ - %@')
});