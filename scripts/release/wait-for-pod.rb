#!/usr/bin/env ruby
# frozen_string_literal: true

# Poll CocoaPods until a pod version is visible (read-only): `pod trunk info` and/or `pod spec cat`.
# Use between ordered `pod trunk push` steps when CDN/propagation is slow.
# Debug: VERBOSE=1 for extra traces (same intent as debugPrint in app code).
#
# Usage:
#   ruby scripts/release/wait-for-pod.rb PayUIndia-OLWParams-SDK 1.0.0.alpha.4
#   ruby scripts/release/wait-for-pod.rb PayUIndia-OLWCore-SDK 1.0.0.alpha.5 --interval 60 --max-wait-seconds 3600

require 'optparse'
require 'open3'

def debug(msg)
  warn "[wait-for-pod] #{msg}" if ENV['VERBOSE'].to_s == '1'
end

def trunk_info_includes_version?(pod, version)
  cmd = ['pod', 'trunk', 'info', pod]
  debug("running: #{cmd.join(' ')}")
  stdout, stderr, status = Open3.capture3(*cmd)
  text = "#{stdout}#{stderr}"
  unless status.success?
    debug("trunk info failed: #{text.strip[0, 500]}")
    return false
  end
  # Avoid "1.0.0" matching "11.0.0" — require version as a standalone token (line or delimiter).
  re = /(^|[\s,;()])#{Regexp.escape(version)}([\s,;()]|$)/m
  text.match?(re)
end

# Fallback: once CDN updates, `pod spec cat` often shows the new `s.version` quickly.
def spec_cat_shows_version?(pod, version)
  cmd = ['pod', 'spec', 'cat', pod]
  debug("running: #{cmd.join(' ')}")
  stdout, stderr, status = Open3.capture3(*cmd)
  text = "#{stdout}#{stderr}"
  return false unless status.success?

  text.each_line.any? { |l| l.match?(/^\s*s\.version\s*=\s*["']#{Regexp.escape(version)}["']/) }
end

def published_either_way?(pod, version)
  trunk_info_includes_version?(pod, version) || spec_cat_shows_version?(pod, version)
end

options = { interval: 30, max_wait: 3600 }
parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/release/wait-for-pod.rb POD_NAME VERSION [options]"
  opts.on('--interval SECONDS', Integer, 'Sleep between attempts (default: 30)') { |v| options[:interval] = v }
  opts.on('--max-wait-seconds SECONDS', Integer, 'Give up after this many seconds (default: 3600)') do |v|
    options[:max_wait] = v
  end
end
parser.parse!

pod = ARGV[0]
version = ARGV[1]
if pod.to_s.empty? || version.to_s.empty?
  warn parser.help
  exit 2
end

start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
attempt = 0

loop do
  attempt += 1
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
  if published_either_way?(pod, version)
    warn "[wait-for-pod] OK: #{pod} #{version} visible after #{elapsed.round(1)}s (#{attempt} attempt(s))"
    exit 0
  end
  if elapsed >= options[:max_wait]
    warn "[wait-for-pod] TIMEOUT: #{pod} #{version} not visible after #{options[:max_wait]}s"
    exit 1
  end
  warn "[wait-for-pod] waiting… #{pod} @ #{version} (attempt #{attempt}, #{elapsed.round(0)}s elapsed, next in #{options[:interval]}s)"
  sleep(options[:interval])
end
