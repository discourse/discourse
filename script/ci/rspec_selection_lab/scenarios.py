import os
import subprocess


PATH_CASES = {
    "routes": "config/routes.rb",
    "locale": "config/locales/server.en.yml",
    "ruby_dependencies": "Gemfile",
    "ruby_lockfile": "Gemfile.lock",
    "javascript_lockfile": "pnpm-lock.yaml",
    "markdown_bundle": "frontend/pretty-text/addon/guid.js",
    "stylesheet_bundle": "app/assets/stylesheets/variable-renames.json",
    "view_template": "app/views/topics/show.html.erb",
    "shared_fabricator": "spec/fabricators/user_fabricator.rb",
    "database_structure": "db/structure.sql",
    "ci_workflow": ".github/workflows/tests.yml",
}
ARTIFACT_CASES = [
    "expired_mapping", "oversized_mapping", "wrong_workflow", "wrong_event",
    "fork_mapping", "wrong_branch", "revision_mismatch", "missing_zip_member",
    "invalid_schema", "missing_spec_entry", "download_error",
]
CASES = [
    "javascript_file_read", "javascript_boot_read", "server_bundle_regression", "native_accessor_cache", "delegated_native_cache", "new_plugin_locale", "ruby_constant", "boot_cached_value", "method_signature", "deleted_source", "audit_subset", "audit_miss_control", "full_override", "audit_override", "model_validation", "controller_status", "scheduled_job", "pending_migration", "password_hash", "mentions", "archetype", "multiple_helpers", "renamed_spec",
    "deleted_spec", "renamed_source", "shared_support", "new_model_discovery",
    "data_dependency", "consumer_missing", "consumer_corrupt", "consumer_stale",
    *PATH_CASES, *ARTIFACT_CASES,
]


def write(workspace, path, content):
    target = workspace / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)


def setup(workspace):
    write(workspace, "plugins/chat/config/locale-rspec-lab/server.en.yml", "en:\n  value: good\n")
    write(workspace, "spec/requests/rspec_lab_locale_discovery_spec.rb", '''require "rails_helper"
RSpec.describe "Locale inventory" do
  it "has no additional plugin locales" do
    locales = Dir[Rails.root.join("plugins/chat/config/locale-rspec-lab/*.yml")]
    expect(locales.reject { |path| path.end_with?(".en.yml") }).to eq([])
  end
end
''')
    write(workspace, "lib/rspec_lab_native_producer.rb", '''module RspecLabNativeProducer
  def self.values
    { first: "good", second: "good" }
  end
end
''')
    write(workspace, "lib/rspec_lab_native_cache.rb", '''require_relative "rspec_lab_native_producer"
class RspecLabNativeCache
  class << self
    attr_reader :values
    def populate
      @values = RspecLabNativeProducer.values
    end
  end
end
''')
    for directory, key in [("integrity", "first"), ("requests", "second")]:
        write(workspace, f"spec/{directory}/rspec_lab_native_{key}_spec.rb", f'''require "rails_helper"
require "rspec_lab_native_cache"
RSpec.describe "{key} native cache consumer" do
  before {{ RspecLabNativeCache.populate unless RspecLabNativeCache.values }}
  it("preserves the value") {{ expect(RspecLabNativeCache.values.fetch(:{key})).to eq("good") }}
end
''')
    write(workspace, "lib/rspec_lab_graph.rb", '''module RspecLabGraph
  def self.model_names
    Dir.glob(Rails.root.join("app/models/rspec_lab_extensions/*.rb")).map { |path| File.basename(path, ".rb") }
  end

  def self.data_value
    JSON.parse(File.read(Rails.root.join("frontend/rspec-lab/value.json"))).fetch("value")
  end
end
''')
    write(workspace, "frontend/rspec-lab/value.json", '{"value":"good"}\n')
    write(workspace, "spec/requests/rspec_lab_discovery_spec.rb", '''require "rails_helper"
require "rspec_lab_graph"

RSpec.describe "Extension discovery" do
  it "has no extensions configured" do
    expect(RspecLabGraph.model_names).to eq([])
  end
end
''')
    write(workspace, "spec/lib/rspec_lab_data_spec.rb", '''require "rails_helper"
require "rspec_lab_graph"

RSpec.describe RspecLabGraph do
  it "reads the configured value" do
    expect(RspecLabGraph.data_value).to eq("good")
  end
end
''')
    write(workspace, "spec/models/rspec_lab_inventory_spec.rb", '''require "rails_helper"

RSpec.describe "Model inventory probe" do
  it "preserves the default archetype" do
    expect(Archetype.default).to eq("regular")
  end
end
''')

    write(workspace, "frontend/discourse/app/rspec-lab-data.js", 'export default "good";\n')
    write(workspace, "frontend/discourse/app/rspec-lab-boot.js", 'export default "good";\n')
    write(workspace, "lib/rspec_lab_javascript.rb", '''module RspecLabJavascript
  def self.value
    File.read(Rails.root.join("frontend/discourse/app/rspec-lab-data.js")).split('"')[1]
  end
end
''')
    write(workspace, "lib/rspec_lab_file_boot.rb", '''module RspecLabFileBoot
  VALUE = File.read(Rails.root.join("frontend/discourse/app/rspec-lab-boot.js")).split('"')[1]
end
''')
    write(workspace, "spec/requests/rspec_lab_javascript_spec.rb", '''require "rails_helper"
require "rspec_lab_javascript"
require "rspec_lab_file_boot"
RSpec.describe "Ruby file inputs" do
  it("reads JavaScript data") { expect(RspecLabJavascript.value).to eq("good") }
  it("preserves boot data") { expect(RspecLabFileBoot::VALUE).to eq("good") }
end
''')
    write(workspace, "spec/lib/rspec_lab_bundle_spec.rb", '''require "rails_helper"
RSpec.describe "Server bundle input" do
  it "escapes HTML through the bundled module" do
    expect(PrettyText.v8.eval(%q{require("discourse/lib/escape").default("<")})).to eq("&lt;")
  end
end
''')
    write(workspace, "lib/rspec_lab_constants.rb", 'module RspecLabConstants\n  VALUE = "good"\nend\n')
    write(workspace, "lib/rspec_lab_boot.rb", 'module RspecLabBoot\n  def self.value\n    "good"\n  end\n  VALUE = value\nend\n')
    for module, label in [("RspecLabConstants", "constants"), ("RspecLabBoot", "boot")]:
        for directory, description in [("lib", module), ("requests", f'"{module} consumer"')]:
            write(workspace, f"spec/{directory}/rspec_lab_{label}_spec.rb", f'require "rails_helper"\nrequire "rspec_lab_{label}"\nRSpec.describe {description} do\n  it("preserves the configured value") {{ expect({module}::VALUE).to eq("good") }}\nend\n')
    write(workspace, "spec/requests/rspec_lab_password_spec.rb", 'require "rails_helper"\nRSpec.describe "Password consumer" do\n  it("returns a password digest") { expect(Pbkdf2.hash_password("password", "salt", 1)).to match(/\\A[0-9a-f]{64}\\z/) }\nend\n')


def apply(workspace, name, *, append, replace, break_helper):
    mode = "subset"
    failures = True
    if name == "javascript_file_read":
        mode = "full"
        write(workspace, "frontend/discourse/app/rspec-lab-data.js", 'export default "broken";\n')
    elif name == "native_accessor_cache":
        replace(workspace, "lib/rspec_lab_native_cache.rb", '@values = RspecLabNativeProducer.values', '@values = RspecLabNativeProducer.values.merge(second: "broken")')
    elif name == "delegated_native_cache":
        replace(workspace, "lib/rspec_lab_native_producer.rb", 'second: "good"', 'second: "broken"')
    elif name == "new_plugin_locale":
        mode = "full"
        write(workspace, "plugins/chat/config/locale-rspec-lab/server.zz.yml", "wrong:\n  value: broken\n")
    elif name == "javascript_boot_read":
        mode = "full"
        write(workspace, "frontend/discourse/app/rspec-lab-boot.js", 'export default "broken";\n')
    elif name == "server_bundle_regression":
        replace(workspace, "frontend/discourse/app/lib/escape.js", '\"<\": \"&lt;\"', '\"<\": \"BROKEN\"')
        mode = "full"
    elif name == "ruby_constant":
        replace(workspace, "lib/rspec_lab_constants.rb", 'VALUE = "good"', 'VALUE = "broken"')
    elif name == "boot_cached_value":
        replace(workspace, "lib/rspec_lab_boot.rb", '    "good"', '    "broken"')
    elif name == "method_signature":
        replace(workspace, "lib/url_helper.rb", "def self.normalized_encode(uri)", "def self.normalized_encode(uri, required:)")
    elif name == "deleted_source":
        (workspace / "lib/pbkdf2.rb").unlink()
        (workspace / "spec/lib/pbkdf2_spec.rb").unlink()
        mode = "full"
    elif name in ["audit_subset", "audit_miss_control", "full_override", "audit_override"]:
        break_helper(workspace)
        if name == "full_override":
            mode = "full"
    elif name == "model_validation":
        replace(workspace, "app/models/badge_grouping.rb", "maximum: 100", "maximum: 99")
    elif name == "controller_status":
        replace(workspace, "app/controllers/offline_controller.rb", 'render :offline, content_type: "text/html"', 'render :offline, content_type: "text/html", status: 404')
    elif name == "scheduled_job":
        replace(workspace, "app/jobs/scheduled/create_missing_avatars.rb", "    def execute(args)\n", '    def execute(args)\n      raise "RspecLab job regression"\n')
    elif name == "view_template":
        replace(workspace, "app/views/topics/show.html.erb", "rel: 'alternate nofollow'", "rel: 'alternate'")
        mode = "full"
    elif name == "pending_migration":
        subprocess.run(["bin/rails", "generate", "migration", "RspecLabPending"], cwd=workspace,
                       env=dict(os.environ, RAILS_ENV="test"), check=True, timeout=90,
                       stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
        mode = "full"
        failures = False
    elif name in PATH_CASES:
        path = PATH_CASES[name]
        target = workspace / path
        if not target.exists():
            raise RuntimeError(f"Scenario input does not exist: {path}")
        if name == "javascript_lockfile":
            target.write_text("# Local lockfile change probe\n" + target.read_text())
        else:
            append(workspace, path, "\n")
        break_helper(workspace)
        mode = "full"
    elif name in ARTIFACT_CASES or name.startswith("consumer_"):
        break_helper(workspace)
        if name != "missing_spec_entry":
            mode = "full"
    elif name == "password_hash":
        anchor = '  def self.hash_password(password, salt, iterations, algorithm = "sha256", length: 32)\n'
        replace(workspace, "lib/pbkdf2.rb", anchor, anchor + '    return "broken"\n')
    elif name == "mentions":
        replace(workspace, "lib/plaintext_mentions.rb", "  def usernames\n", "  def usernames\n    return []\n")
    elif name == "archetype":
        replace(workspace, "lib/archetype.rb", '    "regular"\n', '    "broken"\n')
    elif name == "multiple_helpers":
        break_helper(workspace)
        replace(workspace, "lib/plaintext_mentions.rb", "  def usernames\n", "  def usernames\n    return []\n")
    elif name == "renamed_spec":
        (workspace / "spec/lib/url_helper_spec.rb").rename(workspace / "spec/lib/url_helper.renamed_spec.rb")
        break_helper(workspace)
    elif name == "deleted_spec":
        (workspace / "spec/lib/pbkdf2_spec.rb").unlink()
        break_helper(workspace)
    elif name == "renamed_source":
        mode = "full"
        original = workspace / "lib/url_helper.rb"
        original.rename(workspace / "lib/rspec_lab_url_helper.rb")
        original.write_text('require_relative "rspec_lab_url_helper"\n')
        replace(workspace, "lib/rspec_lab_url_helper.rb", "  def self.normalized_encode(uri)\n", '  def self.normalized_encode(uri)\n    return "https://broken.invalid"\n')
    elif name == "shared_support":
        write(workspace, "spec/support/rspec_lab_regression.rb", '''require "url_helper"
UrlHelper.define_singleton_method(:normalized_encode) { |uri| "https://broken.invalid" }
''')
        mode = "full"
    elif name == "new_model_discovery":
        mode = "full"
        write(workspace, "app/models/rspec_lab_extensions/surprise.rb", "class RspecLabExtensions::Surprise\nend\n")
    elif name == "data_dependency":
        mode = "full"
        write(workspace, "frontend/rspec-lab/value.json", '{"value":"broken"}\n')
    else:
        raise ValueError(name)
    return mode, failures
