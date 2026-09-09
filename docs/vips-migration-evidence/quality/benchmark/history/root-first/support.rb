def probe_quality(backend:, sample:)
  input_path = Rails.root.join(sample.fetch("path")).to_s
  if backend == :imagemagick
    ImageMagick.image_quality(input_path:, timeout: 5)
  else
    DiscourseVips.image_quality(input_path:, input_format: sample.fetch("input_format"), timeout: 5)
  end
end

def quality_outcome(backend:, sample:)
  { status: "ok", value: probe_quality(backend:, sample:) }
rescue StandardError => error
  { status: "error", error: { class: error.class.name, message: error.message } }
end

def timed_quality(backend:, sample:)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  outcome = quality_outcome(backend:, sample:)
  outcome.merge(elapsed_ms: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000)
end

def quality_distribution(values)
  sorted = values.sort
  { values_ms: values, median_ms: sorted[sorted.length / 2], p95_ms: sorted[(sorted.length * 0.95).ceil - 1], min_ms: sorted.first, max_ms: sorted.last }
end

def quality_provenance(mode)
  {
    mode:,
    source: JSON.parse(File.read(Rails.root.join("source-manifest.json"))),
    harness_sha256: %w[boot.rb support.rb prepare.rb benchmark.rb matrix.rb].to_h { |path| [path, Digest::SHA256.file(Rails.root.join(path)).hexdigest] },
    ruby: RUBY_DESCRIPTION,
    libvips: DiscourseVips.version,
    imagemagick: ImageMagick.magick("--version", operation: :benchmark_version).lines.first.strip,
    landlock: Landlock.supported?,
    image: { tag: "discourse/base:2.0.20260812-0036", digest: "sha256:837e8ed4b5916baa36856b842ad84fe262b6b1b5550701f8844b13cc7acad7a5", deployment_override_verified: false },
    query_semantics: "Actual ImageMagick.image_quality on the whole file, without a frame0 suffix; actual DiscourseVips.image_quality facade and sandbox. Animated/multipage concatenation is preserved, not reduced to a nominal quality range.",
  }
end
