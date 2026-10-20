# frozen_string_literal: true

class MisdatedWidgetsChange < JsonApiKit::VersionChange
  version "2026-09-02"
  description "A change whose file name does not start with its version."
end
