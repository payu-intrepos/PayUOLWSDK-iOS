#!/usr/bin/env ruby
# frozen_string_literal: true

# Offline checks for versions.yaml vs repo (podspecs, xcframeworks, dependency keys).
# Does not run pod install / trunk. Debug: VERBOSE=1
#
# Usage:
#   ruby scripts/release/validate-manifest.rb
#   ruby scripts/release/validate-manifest.rb --require-xcframeworks

require 'yaml'

ROOT = File.expand_path('../..', __dir__)
MANIFEST = File.join(ROOT, 'versions.yaml')

def debug(msg)
  warn "[validate-manifest] #{msg}" if ENV['VERBOSE'].to_s == '1'
end

def semverish?(s)
  s.to_s.match?(/\A\d+\.\d+\.\d+(\.[a-zA-Z0-9.]+)?\z/)
end

def read_podspec_version(path)
  body = File.read(path)
  m = body.match(/^\s*s\.version\s*=\s*["']([^"']+)["']/)
  m ? m[1] : nil
end

def podspec_bodies(podspec_paths)
  podspec_paths.filter_map do |p|
    next unless File.file?(p)

    [p, File.read(p)]
  end.to_h
end

def podspecs_mention_dependency?(bodies, dep_name)
  bodies.values.any? { |body| body.include?("'#{dep_name}'") || body.include?(%("#{dep_name}")) }
end

def main
  require_xc = ARGV.include?('--require-xcframeworks')
  errors = 0
  warnings = 0

  unless File.file?(MANIFEST)
    warn "[validate-manifest] missing #{MANIFEST}"
    exit 2
  end

  m = YAML.load_file(MANIFEST)
  debug("loaded #{MANIFEST}")

  internal = m['internal_pods'] || {}
  ext = m['cocoapods_external'] || {}
  release = m['release'] || {}
  order = release['trunk_push_order'] || %w[PayUIndia-OLWParams-SDK PayUIndia-OLWCore-SDK PayUIndia-OLWUI-SDK]
  xfs = release['vendored_xcframeworks'] || []

  podspec_paths = internal.keys.map { |pod| File.join(ROOT, "#{pod}.podspec") }
  bodies = podspec_bodies(podspec_paths)

  puts '=== validate-manifest (offline) ==='

  internal.each do |pod, ver|
    unless semverish?(ver)
      warn "[validate-manifest] ERROR: #{pod} version not semver-ish: #{ver.inspect}"
      errors += 1
    end

    spec = File.join(ROOT, "#{pod}.podspec")
    unless File.file?(spec)
      warn "[validate-manifest] ERROR: missing podspec #{spec}"
      errors += 1
      next
    end

    pv = read_podspec_version(spec)
    if pv && pv != ver
      warn "[validate-manifest] WARN: #{pod}: podspec s.version #{pv.inspect} != versions.yaml #{ver.inspect} (run sync-versions.rb)"
      warnings += 1
    end
  end

  order.each do |pod|
    unless internal.key?(pod)
      warn "[validate-manifest] ERROR: trunk_push_order lists #{pod} but it is missing from internal_pods"
      errors += 1
    end
  end

  ext.each_key do |dep|
    unless podspecs_mention_dependency?(bodies, dep)
      warn "[validate-manifest] WARN: cocoapods_external key #{dep} not referenced in OLW podspecs (typo or unused?)"
      warnings += 1
    end
  end

  spm = m.dig('spm', 'packages')
  if spm.nil? || spm.empty?
    warn '[validate-manifest] ERROR: spm.packages missing or empty'
    errors += 1
  end

  xfs.each do |name|
    path = File.join(ROOT, name)
    next if name.to_s.empty?

    unless File.directory?(path)
      msg = "[validate-manifest] #{require_xc ? 'ERROR' : 'WARN'}: missing xcframework dir #{path}"
      warn msg
      require_xc ? (errors += 1) : (warnings += 1)
    end
  end

  meta_url = m.dig('metadata', 'git_source_url')
  warn '[validate-manifest] WARN: metadata.git_source_url missing' if meta_url.to_s.empty?

  puts "Summary: #{errors} error(s), #{warnings} warning(s)."
  exit(errors.positive? ? 1 : 0)
end

main
