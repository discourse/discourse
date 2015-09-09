const StaleResult = function() {
  this.hasResults = false;
};

StaleResult.prototype.setResults = function(results) {
  if (results) {
    this.results = results;
    this.hasResults = true;
  }
};

export default StaleResult;
