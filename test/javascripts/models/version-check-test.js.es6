import VersionCheck from 'admin/models/version-check';

module("VersionCheck");

test('dataIsOld', function() {
  var dataIsOld = function(args, expected, message) {
    equal(VersionCheck.create(args).get('dataIsOld'), expected, message);
  };

  dataIsOld({updated_at: moment().subtract(2, 'hours').toJSON()},  false, '2 hours ago');
  dataIsOld({updated_at: moment().subtract(49, 'hours').toJSON()}, true,  '49 hours ago');
  dataIsOld({updated_at: moment().subtract(2, 'hours').toJSON(), version_check_pending: true},  true, 'version check pending');
});

test('staleData', function() {
  var updatedAt = function(hoursAgo) {
    return moment().subtract(hoursAgo, 'hours').toJSON();
  };
  var staleData = function(args, expected, message) {
    equal(VersionCheck.create(args).get('staleData'), expected, message);
  };

  staleData({missing_versions_count: 0, installed_version: '0.9.3', latest_version: '0.9.3', updated_at: updatedAt(2)}, false, 'up to date');
  staleData({missing_versions_count: 0, installed_version: '0.9.4', latest_version: '0.9.3', updated_at: updatedAt(2)}, true,  'installed and latest do not match, but missing_versions_count is 0');
  staleData({missing_versions_count: 1, installed_version: '0.9.3', latest_version: '0.9.3', updated_at: updatedAt(2)}, true,  'installed and latest match, but missing_versions_count is not 0');
  staleData({missing_versions_count: 0, installed_version: '0.9.3', latest_version: '0.9.3', updated_at: updatedAt(50)}, true, 'old version check data');
  staleData({version_check_pending: true, missing_versions_count: 0, installed_version: '0.9.4', latest_version: '0.9.3', updated_at: updatedAt(2)}, true, 'version was upgraded, but no version check has been done since the upgrade');
});
