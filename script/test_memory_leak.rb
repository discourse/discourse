# frozen_string_literal: true

# simple test to check for memory leaks
#
# this performs a trivial operation walking all multisites and grabbing first topic / localizing
# the expectation is that RSS will remain static no matter how many iterations run

if ENV['RAILS_ENV'] != "production"
  exec "RAILS_ENV=production ruby #{__FILE__}"
end

if !ENV['LD_PRELOAD']
  exec "LD_PRELOAD=/usr/lib/libjemalloc.so.1 ruby #{__FILE__}"
end

if ENV['LD_PRELOAD'].include?("jemalloc")
  # for 3.6.0 we need a patch jemal 1.1.0 gem (1.1.1 does not support 3.6.0)
  # however ffi is a problem so we need to patch the gem
  require 'jemal'

  $jemalloc = true
end

if ENV['LD_PRELOAD'].include?("mwrap")
  $mwrap = true
  require 'mwrap'
end

def bin_diff(current)
  $baseline[:arenas].each_with_index do |arena, i|
    next if !arena || !arena[:bins]
    arena[:bins].each do |size, stat|
      allocated = (current.dig(:arenas, i, :bins, size, :allocated) || 0)
      diff = allocated - stat[:allocated]
      puts "bin #{size} delta #{diff}"
    end
  end
end

require File.expand_path("../../config/environment", __FILE__)

Rails.application.routes.recognize_path('abc') rescue nil
I18n.t(:posts)

def rss
  `ps -o rss -p #{$$}`.chomp.split("\n").last.to_i
end

def loop_sites
  RailsMultisite::ConnectionManagement.each_connection do
    yield
  end
end

def biggest_klass(klass)
  ObjectSpace.each_object(klass).max { |a, b| a.length <=> b.length }
end

def iter(warmup: false)
  loop_sites { Topic.first; I18n.t('too_late_to_edit') }
  if !warmup
    GC.start(full_mark: true, immediate_sweep: true)

    if $jemalloc
      jemal_stats = Jemal.stats
      jedelta = "(jdelta #{jemal_stats[:active] - $baseline_jemalloc_active})"
    end

    if $mwrap
      mwrap_delta = (Mwrap.total_bytes_allocated - Mwrap.total_bytes_freed) - $mwrap_baseline
      mwrap_delta = "(mwrap delta #{mwrap_delta})"
    end

    rss_delta = rss - $baseline_rss
    array_delta = biggest_klass(Array).length - $biggest_array_length
    puts "rss: #{rss} (#{rss_delta}) #{mwrap_delta}#{jedelta} heap_delta: #{GC.stat[:heap_live_slots] - $baseline_slots} array_delta: #{array_delta}"

    if $jemalloc
      bin_diff(jemal_stats)
    end
  end

end

iter(warmup: true)
4.times do
  GC.start(full_mark: true, immediate_sweep: true)
end

if $jemalloc
  $baseline = Jemal.stats
  $baseline_jemalloc_active = $baseline[:active]
  4.times do
    GC.start(full_mark: true, immediate_sweep: true)
  end
end

def render_table(array)
  buffer = +""

  width = array[0].map { |k| k.to_s.length }
  cols = array[0].length

  array.each do |row|
    row.each_with_index do |val, i|
      width[i] = [width[i].to_i, val.to_s.length].max
    end
  end

  array[0].each_with_index do |col, i|
    buffer << col.to_s.ljust(width[i], ' ')
    if i == cols - 1
      buffer << "\n"
    else
      buffer << ' | '
    end
  end

  buffer << ("-" * (width.sum + width.length))
  buffer << "\n"

  array.drop(1).each do |row|
    row.each_with_index do |val, i|
      buffer << val.to_s.ljust(width[i], ' ')
      if i == cols - 1
        buffer << "\n"
      else
        buffer << ' | '
      end
    end
  end

  buffer
end

def mwrap_log
  report = +""

  Mwrap.quiet do
    report << "Allocated bytes: #{Mwrap.total_bytes_allocated} Freed bytes: #{Mwrap.total_bytes_freed}\n"
    report << "\n"

    table = []
    Mwrap.each(200000) do |loc, total, allocations, frees, age_sum, max_life|
      table << [total, allocations - frees, frees == 0 ? -1 : (age_sum / frees.to_f).round(2), max_life, loc]
    end

    table.sort! { |a, b| b[1] <=> a[1] }
    table = table[0..50]

    table.prepend(["total", "delta", "mean_life", "max_life", "location"])

    report << render_table(table)
  end

  report
end

Mwrap.clear

if $mwrap
  $mwrap_baseline = Mwrap.total_bytes_allocated - Mwrap.total_bytes_freed
end

$baseline_slots = GC.stat[:heap_live_slots]
$baseline_rss = rss
$biggest_array_length = biggest_klass(Array).length

100000.times do
  iter
  if $mwrap
    puts mwrap_log
    GC.start(full_mark: true, immediate_sweep: true)
  end
end
