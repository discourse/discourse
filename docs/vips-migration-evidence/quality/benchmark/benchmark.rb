corpus_path = Rails.root.join("corpus.json")
samples = JSON.parse(File.read(corpus_path)).fetch("samples")
samples.each do |sample|
  raise "Prepared input changed: #{sample.fetch('path')}" unless Digest::SHA256.file(Rails.root.join(sample.fetch("path"))).hexdigest == sample.fetch("sha256")
end
result_path = ENV.fetch("RESULT_PATH", Rails.root.join("quality-results.json").to_s)
raise "Preserve existing benchmark results" if File.exist?(result_path)
report = {
  provenance: quality_provenance("benchmark"),
  corpus_sha256: Digest::SHA256.file(corpus_path).hexdigest,
  warm_iterations: 31,
  fresh_worker_iterations: 5,
  timing_boundary: "Actual public quality query, including instrumentation wrapper, sandbox and IPC/process execution; no Rails boot, fixture generation, source format discovery or FileHelper optimization. Fresh workers retain filesystem caches; reset happens outside timing.",
  samples: [],
  fresh_worker: [],
}
samples.each do |sample|
  validation = %i[imagemagick libvips].to_h { |backend| [backend, quality_outcome(backend:, sample:)] }
  matching_values = validation.values.all? { |outcome| outcome[:status] == "ok" } && validation[:imagemagick][:value] == validation[:libvips][:value]
  if sample.key?("expected_quality_integer")
    matching_values &&= validation[:imagemagick][:value] == sample.fetch("expected_quality_integer")
  end
  expected_unsupported = sample["expected_outcome"] == "unsupported" &&
    validation.values.all? { |outcome| outcome[:status] == "error" } &&
    validation[:imagemagick].dig(:error, :message).include?("no decode delegate") &&
    validation[:libvips].dig(:error, :message).include?("unsupported input format")
  classification = matching_values ? "matching_values" : expected_unsupported ? "expected_unsupported" : "divergent_or_failed"
  record = { sample:, validation:, classification:, compatible: matching_values || expected_unsupported, warm: { imagemagick: [], libvips: [] } }
  if matching_values
    31.times do |iteration|
      order = iteration.even? ? %i[imagemagick libvips] : %i[libvips imagemagick]
      order.each do |backend|
        outcome = timed_quality(backend:, sample:)
        record[:warm][backend] << outcome.merge(iteration: iteration + 1)
        record[:compatible] = false unless outcome[:status] == "ok" && outcome[:value] == validation[backend][:value]
      end
      break unless record[:compatible]
    end
    if record[:compatible]
      record[:timing] = record[:warm].to_h { |backend, outcomes| [backend, quality_distribution(outcomes.map { |outcome| outcome.fetch(:elapsed_ms) })] }
    end
  end
  report[:samples] << record
  File.write(result_path, JSON.pretty_generate(report) + "\n")
  puts JSON.generate({ sample: sample.fetch("name"), compatible: record[:compatible] })
end
photo = report[:samples].find { |record| record[:sample].fetch("name") == "jpeg-photo" }
if photo[:compatible]
  5.times do |iteration|
    DiscourseVips.before_fork
    outcome = timed_quality(backend: :libvips, sample: photo[:sample])
    report[:fresh_worker] << outcome.merge(iteration: iteration + 1, compatible: outcome[:status] == "ok" && outcome[:value] == photo[:validation][:libvips][:value])
    File.write(result_path, JSON.pretty_generate(report) + "\n")
  end
end
report[:inputs_unchanged] = samples.all? { |sample| Digest::SHA256.file(Rails.root.join(sample.fetch("path"))).hexdigest == sample.fetch("sha256") }
report[:compatible] = report[:inputs_unchanged] && report[:samples].all? { |record| record[:compatible] } && report[:fresh_worker].length == 5 && report[:fresh_worker].all? { |outcome| outcome[:compatible] }
File.write(result_path, JSON.pretty_generate(report) + "\n")
DiscourseVips.before_fork
exit(report[:compatible] ? 0 : 1)
