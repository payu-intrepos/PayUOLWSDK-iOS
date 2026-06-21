#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints release plan from versions.yaml only (no network, no git writes).
# Use before ./scripts/release/release.sh to verify tags, trunk order, and versions.
# Debug: VERBOSE=1
#
# Usage: ruby scripts/release/print-trunk-plan.rb

require 'yaml'

ROOT = File.expand_path('../..', __dir__)
MANIFEST = File.join(ROOT, 'versions.yaml')

def debug(msg)
  warn "[print-trunk-plan] #{msg}" if ENV['VERBOSE'].to_s == '1'
end

def load_manifest
  unless File.file?(MANIFEST)
    warn "[print-trunk-plan] Missing #{MANIFEST}"
    exit 1
  end
  YAML.load_file(MANIFEST)
end

def main
  m = load_manifest
  debug("loaded #{MANIFEST}")

  internal = m['internal_pods'] || {}
  release = m['release'] || {}
  order = release['trunk_push_order']
  order ||= %w[PayUIndia-OLWParams-SDK PayUIndia-OLWCore-SDK PayUIndia-OLWUI-SDK]

  meta = m['metadata'] || {}
  git_url = meta['git_source_url']

  puts '=== OLW release plan (local manifest only) ==='
  puts
  puts 'Git source (CocoaPods :git / tags):'
  puts "  #{git_url || '(metadata.git_source_url missing)'}"
  puts

  puts 'Unique semver tags implied by internal_pods (same as release.sh tagging):'
  tags = internal.values.compact.uniq.sort
  if tags.empty?
    puts '  (none)'
  else
    tags.each { |t| puts "  #{t}" }
  end
  puts

  puts 'Trunk push order → podspec path → version from internal_pods:'
  order.each_with_index do |pod, i|
    ver = internal[pod]
    spec = File.join(ROOT, "#{pod}.podspec")
    exists = File.file?(spec) ? 'ok' : 'MISSING'
    puts "  #{i + 1}. #{pod}"
    puts "       podspec: #{spec} (#{exists})"
    puts "       version: #{ver || '(not in internal_pods)'}"
  end
  puts

  puts 'Vendored xcframeworks (for sync-artifacts.sh):'
  xfs = release['vendored_xcframeworks'] || %w[
    PayUOLWParamKit.xcframework
    PayUOLWCoreKit.xcframework
    PayUOLWUIKit.xcframework
  ]
  xfs.each { |x| puts "  #{x}" }
  puts

  puts 'Next steps (manual):'
  puts '  ruby scripts/release/sync-versions.rb'
  puts '  ./scripts/release/release.sh --dry-run'
  puts '  # real trunk: RELEASE_ALLOW_TRUNK=1 ./scripts/release/release.sh'
  puts
  puts '[print-trunk-plan] done.'
end

main
