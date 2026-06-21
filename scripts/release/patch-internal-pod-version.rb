#!/usr/bin/env ruby
# frozen_string_literal: true

# Updates one internal_pods line in versions.yaml (preserves comments and rest of file).
# Debug: VERBOSE=1
#
# Usage:
#   ruby scripts/release/patch-internal-pod-version.rb PayUIndia-OLWParams-SDK 1.0.0.alpha.6

require 'yaml'

ROOT = File.expand_path('../..', __dir__)
MANIFEST = File.join(ROOT, 'versions.yaml')

def debug(msg)
  warn "[patch-internal-pod-version] #{msg}" if ENV['VERBOSE'].to_s == '1'
end

def semverish?(s)
  s.to_s.match?(/\A\d+\.\d+\.\d+(\.[a-zA-Z0-9.\-+]+)?\z/)
end

def main
  pod = ARGV[0]
  new_ver = ARGV[1]
  if pod.to_s.empty? || new_ver.to_s.empty?
    warn 'Usage: ruby scripts/release/patch-internal-pod-version.rb POD_NAME NEW_VERSION'
    exit 2
  end
  unless semverish?(new_ver)
    warn "[patch-internal-pod-version] ERROR: version does not look semver-ish: #{new_ver.inspect}"
    exit 2
  end

  unless File.file?(MANIFEST)
    warn "[patch-internal-pod-version] missing #{MANIFEST}"
    exit 2
  end

  # Confirm pod exists in manifest (YAML) before line surgery
  m = YAML.load_file(MANIFEST)
  unless m.dig('internal_pods', pod)
    warn "[patch-internal-pod-version] ERROR: #{pod} not found under internal_pods in #{MANIFEST}"
    exit 2
  end

  lines = File.readlines(MANIFEST)
  rx = /^(\s*)#{Regexp.escape(pod)}:\s*"[^"]*"\s*$/
  idx = lines.index { |ln| ln.match?(rx) }
  unless idx
    warn "[patch-internal-pod-version] ERROR: no line matching #{pod}: \"...\" in #{MANIFEST}"
    exit 2
  end

  old = lines[idx]
  lines[idx] = %(#{Regexp.last_match(1)}#{pod}: "#{new_ver}"\n)
  File.write(MANIFEST, lines.join)
  debug("patched line #{idx + 1}")
  warn "[patch-internal-pod-version] updated #{pod} -> #{new_ver.inspect}"
end

main
